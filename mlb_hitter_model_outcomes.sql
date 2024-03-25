/*
  This is a query that I used in MS SQL Server to stage data for fantasy baseball modeling.
  I wanted to rank the players each season by the stat categories we use for scoring in my league:
      Home Runs (HR), Runs Scored (R), Runs Batted In (RBI), Stolen Bases (SB), and On Base Percentage (OBP).
*/

DECLARE @percent_target as decimal(3,2)
SET @percent_target = .66

SELECT
    player_season_key,
    player_id,
    season,
    name,
    age,
    hr,
    r,
    rbi,
    sb,
    opb,
    PERCENT_RANK () over (order by hr)	      as hr_pct
    PERCENT_RANK () over (order by r)	        as r_pct
    PERCENT_RANK () over (order by rbi)	      as rbi_pct
    PERCENT_RANK () over (order by sb)	      as sb_pct
    PERCENT_RANK () over (order by obp)	      as obp_pct,
    PERCENT_RANK () over (order by hr)
      + PERCENT_RANK () over (order by r)
      + PERCENT_RANK () over (order by rbi)
      + PERCENT_RANK () over (order by sb)
      + PERCENT_RANK () over (order by obp)   as total_rank
INTO 
	  ranks_batting_STAGE
FROM
	  stats_batting_majors
WHERE
	  PA >= 400 --I limited the pool of players to be considered a postive outcome to only those with at least 400 plate appearances in the season to reduce anomolous records

--Here we add two more fields to the ranks to capture the overall value of each player across all the categories
if object_id('dbo.ranks_batting') is not null
	drop table dbo.ranks_batting

SELECT 
    *,
    PERCENT_RANK() over (order by total_rank) as percentile, 
    ROW_NUMBER () over (partition by season order by total_rank desc) as season_rank
INTO 
	  ranks_batting
FROM 
	  ranks_batting_STAGE 
ORDER BY
	  season desc
    total_rank desc

--In this final step, we're flagging the players that hit our defined percentage threshold as a postive outcome player
if object_id('dbo.outcomes_batting') is not null
	drop table dbo.outcomes_batting

SELECT
    identity(int,1,1) as model_id,  --This was used in a later step for bootstrapping the historical batting data for modeling
    a.player_season_key,
    a.player_id,
    a.Name,
    a.Season,
    case when b.r_pct >= @percent_target then 1 else 0 end       as r_outcome,
    case when b.rbi_pct >= @percent_target then 1 else 0 end     as rbi_outcome,
    case when b.hr_pct >= @percent_target then 1 else 0 end      as hr_outcome,
    case when b.obp_pct >= @percent_target then 1 else 0 end     as obp_outcome,
    case when b.sb_pct >= @percent_target then 1 else 0 end      as sb_outcome,
    case when b.percentile >= @percent_target then 1 else 0 end  as overall_outcome
INTO
    outcomes_batting
FROM
	  stats_batting_majors a
LEFT JOIN
	  ranks_batting b on a.player_season_key = b.player_season_key
WHERE
	  a.AB >= 100  --Only including players with at least 100 at bats in the season to be modeled
   
DROP table ranks_batting_STAGE

SELECT * from outcomes_batting
