--create table Deliveries with column name and types
create table Deliveries(id int, inning int, over int, ball int, batsman varchar, non_striker varchar, bowler varchar, batsman_runs int,
extra_runs int, total_runs int, is_wicket int, dismissal_kind varchar, player_dismissed varchar, fielder varchar, extras_type varchar,
batting_team varchar, bowling_team varchar);

--import datas from IPL_Ball csv file
copy Deliveries from 'C:\Program Files\PostgreSQL\16\data\data_copy\IPL_Ball.csv' delimiter ',' csv header;
select * from Deliveries where bowler='C Nanda';

--create table Matches with column name and types
create table Matches(id int, city varchar, date varchar, player_of_match varchar, venue varchar, neutral_venue int,	team1 varchar,
team2 varchar, toss_winner varchar, toss_decision varchar,	winner varchar,	result varchar,	result_margin int, eliminator varchar,
method varchar,	umpire1 varchar, umpire2 varchar);

--import datas from IPL_matches csv file
copy Matches from 'C:\Program Files\PostgreSQL\16\data\data_copy\IPL_matches.csv' delimiter ',' csv header;
select * from Matches;

--bidding on agressive batsman
select batsman, batsman_total_score, total_ball_faced, 
round(cast(batsman_total_score as decimal)/cast(total_ball_faced as decimal)*100, 4) AS batting_strike_rate
from (select batsman, sum(batsman_runs) as batsman_total_score, count(ball) as total_ball_faced 
	  from Deliveries where extras_type not in('wides') group by batsman) as subquery 
where total_ball_faced>=500 order by batting_strike_rate desc limit 10;

--bidding on anchor batsman
select batsman, played_IPL_season, batsman_total_score, total_times_dismissal, 
round(cast(batsman_total_score as decimal)/cast(total_times_dismissal as decimal),4) AS players_average
from (select batsman, count(distinct substring(date from 7 for 4)) as played_IPL_season,
	  sum(case when dismissal_kind in ('NA') then batsman_runs else 0 end) as batsman_total_score,
	  count(case when dismissal_kind not in ('NA') then is_wicket end) as total_times_dismissal
	  from (select a.*, b.date from Deliveries as a left join Matches as b on a.id=b.id) group by batsman) as subquery
where total_times_dismissal>=1 and played_IPL_season>2 order by players_average desc limit 10;

--bidding on harde hitters batsman
select batsman, played_IPL_season, batsman_total_score, boundary_hits, runs_from_boundary, 
round(cast(runs_from_boundary as decimal)/cast(batsman_total_score as decimal)*100, 4) AS boundary_precentage
from (select batsman, count(distinct substring(date from 7 for 4)) as played_IPL_season,
	  sum(batsman_runs) as batsman_total_score,
	  count(case when batsman_runs in (4,6) then batsman_runs end) as boundary_hits,
	  sum(case when batsman_runs in (4,6) then batsman_runs else 0 end) as runs_from_boundary
	  from (select a.*, b.date from Deliveries as a left join Matches as b on a.id=b.id) group by batsman) as subquery
where played_IPL_season>2 order by boundary_precentage desc limit 10;

--Bidding on economical bowlers
select bowler, total_runs_conceded, total_balled, total_overs_bowled,
round(cast(total_runs_conceded as decimal)/cast(total_overs_bowled as decimal), 4) AS bowling_economy
from (select bowler, sum(total_runs) as total_runs_conceded, count(ball) as total_balled, 
	  round(cast(count(over) as decimal)/6, 4) as total_overs_bowled 
	  from Deliveries group by bowler) as subquery 
where total_balled>=500 order by bowling_economy desc limit 10;

--Bidding wicket taking bowlers
select bowler, total_balled, total_wicket_taken,
round(cast(total_balled as decimal)/cast(total_wicket_taken as decimal), 4) AS bowling_strike_rate
from (select bowler, count(ball) as total_balled, 
	  count(case when dismissal_kind not in ('NA', 'run out') then dismissal_kind end) as total_wicket_taken 
	  from Deliveries group by bowler) as subquery 
where total_balled>=500 order by bowling_strike_rate desc limit 10;

--Bidding on All rounders
with batting_stats as 
(select batsman, batsman_total_score, total_ball_faced
from (select batsman, sum(batsman_runs) as batsman_total_score, count(ball) as total_ball_faced 
	  from Deliveries where extras_type not in('wides') group by batsman) as subquery where total_ball_faced>=500),
bowling_stats as 
(select bowler, total_balled, total_wicket_taken
from (select bowler, count(ball) as total_balled,
	  count(case when dismissal_kind not in ('NA','run out') then dismissal_kind end) as total_wicket_taken 
	  from Deliveries group by bowler) as subquery where total_balled>=300)
select a.batsman as all_rounder, a.batsman_total_score, a.total_ball_faced, b.bowler as bowler, b.total_wicket_taken, b.total_balled,
    round(cast(a.batsman_total_score as decimal)/cast(a.total_ball_faced as decimal)*100, 4) as batting_strike_rate,
    round(cast(b.total_wicket_taken as decimal)/cast(b.total_balled as decimal)*100, 4) as bowling_strike_rate
from batting_stats a inner join bowling_stats b on a.batsman = b.bowler
order by batting_strike_rate desc, bowling_strike_rate asc limit 10;

--Bidding for wicketkeeper
--I will ensure that in the list of wicketkeepers, bowlers' names are not listed because it can cause difficulties in wicketkeeping 
--when they themselves are bowling.
--Wicketkeeper have good batting strike rate, will be the addition for the team
--will extract the filder name whose fall under categories dismissal_kind is equal 
--to catch and run out, shows the good fielder criteria
--if we have historical data of fall of wicket, because of wicketkeepers with any dismissal_kind then will count the total falls of 
--wicket for same and will target with the highest wicketkeeper 
select w.player_name as wicketkeeper_name,case when w.batting_strike_rate>(select avg(batting_strike_rate) from wicketkeepers) 
then 'Good Batting Strike Rate' else 'Regular Batting Strike Rate' end as batting_performance,
count(f.fall_of_wicket) as total_falls_of_wicket from wicketkeepers w left join bowlers b on w.player_name=b.player_name
join historical_data h on w.player_name = h.wicketkeeper_name join falls_of_wicket f on h.match_id = f.match_id
where b.player_name is NULL and f.dismissal_kind in ('catch', 'run out') group by w.player_name
order by total_falls_of_wicket desc limit 10;

--Additional question for assessment
--Count of cities
select count(distinct city) as cities_hosted_IPL_match from Matches;

--create table deliveries_v02
create table deliveries_v02 as 
(select *, case when total_runs>=4 then 'boundary' when total_runs=0 then 'dot' else 'other' end as ball_result from Deliveries);

--total number of boundaries and dot balls
select count(case when ball_result in ('boundary') then ball_result end) as total_number_of_boundary,
count(case when ball_result in ('dot') then ball_result end) as total_number_of_dot from deliveries_v02;
	   
--total number of boundaries scored by each team	  
select batting_team, count(case when ball_result in ('boundary') then ball_result end) as total_number_of_boundary 
from deliveries_v02 group by batting_team order by total_number_of_boundary desc;

--total number of dot balled by each team	  
select batting_team, count(case when ball_result in ('dot') then ball_result end) as total_number_of_dot 
from deliveries_v02 group by batting_team order by total_number_of_dot desc;

--total number of dismissals for dismissal kind is not equal to NA
select dismissal_kind, count(*) as total_dismissals from deliveries_v03 where dismissal_kind not in('NA') group by dismissal_kind;

--top 5 bowlers who conceded maximum extra runs
select bowler, sum(extra_runs) as total_extra_runs_conceded from Deliveries group by bowler 
order by total_extra_runs_conceded desc limit 5;

--create table deliveries_v03
create table deliveries_v03 as (select a.*, b.venue as venue, b.date as match_date from deliveries_v02 as a inner join Matches as b 
on a.id=b.id);

--total runs scored for each venue
select venue, count(total_runs) as venuewise_total_runs from deliveries_v03 group by venue order by venuewise_total_runs desc;

--yearwise total runs scored at eden gardens
select distinct substring(match_date from 7 for 4) as year, venue, 
count(total_runs) as venuewise_total_runs from deliveries_v03 
where venue='Eden Gardens' group by year, venue order by venuewise_total_runs desc;
