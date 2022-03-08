--1. В каких городах больше одного аэропорта?

select city "Город", count(airport_name) "Количество аэропортов"
from airports a 
group by city
having count(airport_name) > 1

--2. В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?


select distinct a.airport_name "Название аэропортов"
from flights f
left join airports a on f.departure_airport = a.airport_code 
where aircraft_code = (
     select aircraft_code 
     from aircrafts a 
     order by "range" desc 
     limit 1)

--3. Вывести 10 рейсов с максимальным временем задержки вылета

select 
flight_id "Индентификатор рейса", 
flight_no "Номер рейса", 
actual_departure - scheduled_departure "Задержки вылета"
from flights f 
where actual_departure - scheduled_departure is not null
order by actual_departure - scheduled_departure desc 
limit 10

--4. Были ли брони, по которым не были получены посадочные талоны?

select distinct b.book_ref "Номер брони", 
b.book_date "Дата бронирования", 
bp.boarding_no "Посадочный талон"
from 
bookings b 
left join tickets t using(book_ref)
left join boarding_passes bp on t.ticket_no = bp.ticket_no 
where bp.boarding_no is null

--5. Найдите свободные места для каждого рейса, их % отношение к общему количеству мест в самолете.
Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных пассажиров из каждого аэропорта на каждый день. Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек уже вылетело из данного аэропорта на этом или более ранних рейсах за день.

with all_seats as (
     select aircraft_code, count(seat_no)
     from seats s 
     group by aircraft_code 
 ), not_free as (
     select flight_id, count(seat_no)
     from boarding_passes bp 
     group by flight_id
)
select f.flight_id "Идентификатор рейса", 
all_seats.count - not_free.count "Свободные места",
round((all_seats.count - not_free.count) * 100.0 / all_seats.count, 1) "% свободныхх мест", 
f.departure_airport "Аэропорт вылета", 
f.actual_departure::date "Дата вылета", 
sum(not_free.count) over(partition by f.departure_airport, f.actual_departure::date 
order by f.actual_departure), 
not_free.count
from flights f 
left join not_free using(flight_id)
left join all_seats using(aircraft_code)
where f.actual_departure is not null 

--6. Найдите процентное соотношение перелетов по типам самолетов от общего количества.

select 
aircraft_code "Тип самолтеа", 
count(flight_id) "Количество перелетов", 
round(count(flight_id) * 100.0 / (
     select count(flight_id)
     from flights f ), 2) "% от обшего количества"
from flights f 
group by aircraft_code 
order by 3 desc

--7. Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?

with business as (
     select flight_id, fare_conditions, amount 
     from ticket_flights tf 
     where fare_conditions = 'Business'
), economy as (
     select flight_id, fare_conditions, amount 
     from ticket_flights tf 
      where fare_conditions = 'Economy'
), city as (
     select flight_id, f.arrival_airport, a.city 
     from flights f 
     left join airports a on f.arrival_airport = a.airport_code 
)
select city.city "Город", business.flight_id "Идентификатор перелета"
from business 
left join economy using(flight_id)
left join city on business.flight_id = city.flight_id 
where business.amount < economy.amount

--8. Между какими городами нет прямых рейсов?

create view small_1 as (
select F.flight_id, f.departure_airport, a.city 
from flights f 
left join airports a on f.departure_airport = a.airport_code )


create view small_0 as (
select f.flight_id, f.arrival_airport, a.city 
from flights f 
left join airports a on f.arrival_airport = a.airport_code ) 

select a.city, a2.city
from airports a 
cross join airports a2
where a.city != a2.city
except
select small_1.city, small_0.city
from small_1 
left join small_0 on small_1.flight_id = small_0.flight_id

--9. Вычислите расстояние между аэропортами, связанными прямыми рейсами, сравните с допустимой максимальной дальностью перелетов  в самолетах, обслуживающих эти рейсы *

explain analyse 

select 
r.departure_city "Откуда", 
r.arrival_city "Куда", 
6371 * acos(sind(a.latitude) * sind(a2.latitude) + cosd(a.latitude) * 
cosd(a2.latitude) * cosd(a.longitude - a2.longitude)) "Расстояние", 
a3."range" "Мак.расстояние самолета", 
case 
     when 6371 * acos(sind(a.latitude) * sind(a2.latitude) + 
     cosd(a.latitude) * cosd(a2.latitude) * cosd(a.longitude - a2.longitude)) > a3."range"
     then 'Упал'
     else 'Долетел'
end
from routes r 
left join airports a on r.departure_airport = a.airport_code 
left join airports a2 on r.arrival_airport = a2.airport_code 
left join aircrafts a3 on r.aircraft_code = a3.aircraft_code 

select flight_no, count(1)
from flights f 
group by flight_no 