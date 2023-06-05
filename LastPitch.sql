SELECT *
FROM RaysPitching.Dbo.LastPitchRays

SELECT *
FROM RaysPitching.Dbo.RaysPitchingStats


--Question 1 AVG Pitches Per at Bat Analysis

--1a AVG Pitches Per At Bat (LastPitchRays)

SELECT AVG(1.00 * Pitch_number) AvgNumofPitchesPerAtBat
FROM RaysPitching.Dbo.LastPitchRays

--1b AVG Pitches Per At Bat Home Vs Away (LastPitchRays) -> Union

SELECT 
	'Home' TypeofGame,
	AVG(1.00 * Pitch_number) AvgNumofPitchesPerAtBat
FROM RaysPitching.Dbo.LastPitchRays
Where home_team = 'TB'
UNION
SELECT 
	'Away' TypeofGame,
	AVG(1.00 * Pitch_number) AvgNumofPitchesPerAtBat
FROM RaysPitching.Dbo.LastPitchRays
Where away_team = 'TB'

--1c AVG Pitches Per At Bat Lefty Vs Righty  -> Case Statement 

SELECT 
	AVG(Case when batter_position = 'L' Then 1.00 * Pitch_number end) LeftyatBats,
	AVG(Case when batter_position = 'R' Then 1.00 * Pitch_number end) RightyatBats
FROM RaysPitching.Dbo.LastPitchRays

--1d AVG Pitches Per At Bat Lefty Vs Righty Pitcher | Each Away Team -> Partition By

SELECT DISTINCT
	home_team,
	Pitcher_position,
	AVG(1.00 * Pitch_number) OVER (Partition by home_team, Pitcher_position)
FROM RaysPitching.Dbo.LastPitchRays
Where away_team = 'TB'

--1e Top 3 Most Common Pitch for at bat 1 through 10, and total amounts (LastPitchRays)

with totalpitchsequence as (
	SELECT DISTINCT
		Pitch_name,
		Pitch_number,
		count(pitch_name) OVER (Partition by Pitch_name, Pitch_number) PitchFrequency
	FROM RaysPitching.Dbo.LastPitchRays
	where Pitch_number < 11
),
pitchfrequencyrankquery as (
	SELECT 
	Pitch_name,
	Pitch_number,
	PitchFrequency,
	rank() OVER (Partition by Pitch_number order by PitchFrequency desc) PitchFrequencyRanking
FROM totalpitchsequence
)
SELECT *
FROM pitchfrequencyrankquery
WHERE PitchFrequencyRanking < 4

--1f AVG Pitches Per at Bat Per Pitcher with 20+ Innings | Order in descending (LastPitchRays + RaysPitchingStats)

SELECT 
	RPS.Name, 
	AVG(1.00 * Pitch_number) AVGPitches
FROM RaysPitching.Dbo.LastPitchRays LPR
JOIN RaysPitching.Dbo.RaysPitchingStats RPS ON RPS.pitcher_id = LPR.pitcher
WHERE IP >= 20
group by RPS.Name
order by AVG(1.00 * Pitch_number) DESC

--Question 2 Last Pitch Analysis

--2a Count of the Last Pitches Thrown in Desc Order (LastPitchRays)

SELECT pitch_name, count(*) timesthrown
FROM RaysPitching.Dbo.LastPitchRays
group by pitch_name
order by count(*) desc

--2b Count of the different last pitches Fastball or Offspeed (LastPitchRays)

SELECT
	sum(case when pitch_name in ('4-Seam Fastball', 'Cutter') then 1 else 0 end) Fastball,
	sum(case when pitch_name NOT in ('4-Seam Fastball', 'Cutter') then 1 else 0 end) Offspeed
FROM RaysPitching.Dbo.LastPitchRays

--2c Percentage of the different last pitches Fastball or Offspeed (LastPitchRays)

SELECT
	100 * sum(case when pitch_name in ('4-Seam Fastball', 'Cutter') then 1 else 0 end) / count(*) FastballPercent,
	100 * sum(case when pitch_name NOT in ('4-Seam Fastball', 'Cutter') then 1 else 0 end) / count(*) OffspeedPercent
FROM RaysPitching.Dbo.LastPitchRays

--2d Top 5 Most common last pitch for a Relief Pitcher vs Starting Pitcher (LastPitchRays + RaysPitchingStats)

SELECT *
FROM (
	SELECT 
		a.POS, 
		a.pitch_name,
		a.timesthrown,
		RANK() OVER (Partition by a.POS Order by a.timesthrown desc) PitchRank
	FROM (
		SELECT RPS.POS, LPR.pitch_name, count(*) timesthrown
		FROM RaysPitching.Dbo.LastPitchRays LPR
		JOIN RaysPitching.Dbo.RaysPitchingStats RPS ON RPS.pitcher_id = LPR.pitcher
		group by RPS.POS, LPR.pitch_name
	) a
)b
WHERE b.PitchRank < 6


--Question 3 Homerun analysis

--3a What pitches have given up the most HRs (LastPitchRays) 

--Doesnt work due to bad data
--SELECT *
--FROM RaysPitching.Dbo.LastPitchRays
--where hit_location is NULL and bb_type = 'fly_ball'

--actual way to do it
SELECT pitch_name, count(*) HRs
FROM RaysPitching.Dbo.LastPitchRays
where events = 'home_run'
group by pitch_name
order by count(*) desc

--3b Show HRs given up by zone and pitch, show top 5 most common

SELECT TOP 5 ZONE, pitch_name, count(*) HRs
FROM RaysPitching.Dbo.LastPitchRays
where events = 'home_run'
group by ZONE, pitch_name
order by count(*) desc

--3c Show HRs for each count type -> Balls/Strikes + Type of Pitcher

SELECT RPS.POS, LPR.balls,lpr.strikes, count(*) HRs
FROM RaysPitching.Dbo.LastPitchRays LPR
JOIN RaysPitching.Dbo.RaysPitchingStats RPS ON RPS.pitcher_id = LPR.pitcher
where events = 'home_run'
group by RPS.POS, LPR.balls,lpr.strikes
order by count(*) desc

--3d Show Each Pitchers Most Common count to give up a HR (Min 30 IP)

with hrcountpitchers as (
SELECT RPS.Name, LPR.balls,lpr.strikes, count(*) HRs
FROM RaysPitching.Dbo.LastPitchRays LPR
JOIN RaysPitching.Dbo.RaysPitchingStats RPS ON RPS.pitcher_id = LPR.pitcher
where events = 'home_run' and IP >= 30
group by RPS.Name, LPR.balls,lpr.strikes
),
hrcountranks as (
	SELECT 
	hcp.Name, 
	hcp.balls,
	hcp.strikes, 
	hcp.HRs,
	rank() OVER (Partition by Name order by HRs desc) hrrank
	FROM hrcountpitchers hcp
)
SELECT ht.Name, ht.balls, ht.strikes, ht.HRs
FROM hrcountranks ht
where hrrank = 1

--Question 4 Shane McClanahan

--SELECT *
--FROM RaysPitching.Dbo.LastPitchRays LPR
--JOIN RaysPitching.Dbo.RaysPitchingStats RPS ON RPS.pitcher_id = LPR.pitcher


--4a AVG Release speed, spin rate,  strikeouts, most popular zone ONLY USING LastPitchRays

SELECT 
	AVG(release_speed) AvgReleaseSpeed,
	AVG(release_spin_rate) AvgSpinRate,
	Sum(case when events = 'strikeout' then 1 else 0 end) strikeouts,
	MAX(zones.zone) as Zone
FROM RaysPitching.Dbo.LastPitchRays LPR
join (

	SELECT TOP 1 pitcher, zone, count(*) zonenum
	FROM RaysPitching.Dbo.LastPitchRays LPR
	where player_name = 'McClanahan, Shane'
	group by pitcher, zone
	order by count(*) desc

) zones on zones.pitcher = LPR.pitcher
where player_name = 'McClanahan, Shane'

--4b top pitches for each infield position where total pitches are over 5, rank them
SELECT *
FROM (
	SELECT pitch_name, count(*) timeshit, 'Third' Position
	FROM RaysPitching.Dbo.LastPitchRays
	WHERE hit_location = 5 and player_name = 'McClanahan, Shane'
	group by pitch_name
	UNION
	SELECT pitch_name, count(*) timeshit, 'Short' Position
	FROM RaysPitching.Dbo.LastPitchRays
	WHERE hit_location = 6 and player_name = 'McClanahan, Shane'
	group by pitch_name
	UNION
	SELECT pitch_name, count(*) timeshit, 'Second' Position
	FROM RaysPitching.Dbo.LastPitchRays
	WHERE hit_location = 4 and player_name = 'McClanahan, Shane'
	group by pitch_name
	UNION
	SELECT pitch_name, count(*) timeshit, 'First' Position
	FROM RaysPitching.Dbo.LastPitchRays
	WHERE hit_location = 3 and player_name = 'McClanahan, Shane'
	group by pitch_name
) a
where timeshit > 4
order by timeshit desc

--4c Show different balls/strikes as well as frequency when someone is on base 

SELECT balls, strikes, count(*) frequency
FROM RaysPitching.Dbo.LastPitchRays
WHERE (on_3b is NOT NULL or on_2b is NOT NULL or on_1b is NOT NULL)
and player_name = 'McClanahan, Shane'
group by balls, strikes
order by count(*) desc

--4d What pitch causes the lowest launch speed

SELECT TOP 1 pitch_name, avg(launch_speed * 1.00) LaunchSpeed
FROM RaysPitching.Dbo.LastPitchRays
where player_name = 'McClanahan, Shane'
group by pitch_name
order by avg(launch_speed)
