--Create Table with Total World Death data
DROP TABLE If Exists TotalDeathsAllAgesAndCauses
CREATE TABLE TotalDeathsAllAgesAndCauses(
    [Country] nvarchar(max),
    [CountryCode] nvarchar(max),
    [Year] SMALLINT ,
    [AcuteHepatitis] FLOAT,
    [Alcohol use disorders] FLOAT,
    [AlzheimersAndDimentias] FLOAT,
    [Cardiovascular diseases] FLOAT,
    [Chronic kidney disease] FLOAT,
    [Chronic respiratory diseases] FLOAT,
    [Cirrhosis and other chronic liver diseases] FLOAT,
    [ConflictAndTerrorism] FLOAT,
    [DiabetesMellitus] FLOAT,
    [Diarrheal diseases] FLOAT,
    [Digestive diseases] FLOAT,
    [Drowning] FLOAT,
    [Drug use disorders] FLOAT,
    [Environmental heat and cold exposure] FLOAT,
    [Executions] FLOAT,
    [Exposure to forces of nature] FLOAT,
    [Fire, heat, and hot substances] FLOAT,
    [HIV/AIDS] FLOAT,
    [Interpersonal violence] FLOAT,
    [Lower respiratory infections] FLOAT,
    [Malaria] FLOAT,
    [MaternalDisorders] FLOAT,
    [Meningitis] FLOAT,
    [NeonatalDisorders] FLOAT,
    [Neoplasms] FLOAT,
    [Nutritional deficiencies] FLOAT,
    [Parkinson's disease] FLOAT,
    [Poisonings] FLOAT,
    [Protein-energy malnutrition] FLOAT,
    [Road injuries] FLOAT,
    [Self-harm] FLOAT,
    [Tuberculosis] FLOAT,
    [TotalDeathsPerYear] FLOAT
);


BULK 
INSERT dbo.TotalDeathsAllAgesAndCauses
FROM '/TD.csv'
WITH ( FORMAT = 'CSV');

--changing column names as they're complicated to work with
--***to do: change the other tables
EXEC sp_rename 'dbo.SeventyPlusDeathCauses.Age range', 'AgeRange', 'COLUMN';
EXEC sp_rename "dbo.FifteenToFortyNineDeathCauses.AlzheimersAndDimentias", "AlzheimersAndDementias", "COLUMN";

--change column type
ALTER TABLE TotalDeathsAllAgesAndCauses
ALTER COLUMN Country varchar(30)

--Exploring and Cleaning the Data

--Looking at portion of Total Deaths caused from Alzheimer's disease and other dementias
SELECT Country, CountryCode, Year, AlzheimersAndDementias, TotalDeaths, (CAST(AlzheimersAndDementias as float)/TotalDeaths)*100 as 'AlzPercentage', AgeRange
FROM FiftyToSixtyNineDeathCauses
Order by Country

--check what Country names are 'like' United States
--'%' at the end of states returns virgin Islands as well
SELECT Country
FROM FiftyToSixtyNineDeathCauses
WHERE Country like '%states'

 
 --Alz % Deaths in US
SELECT Country, CountryCode, Year, AlzheimersAndDementias, TotalDeaths, (CAST(AlzheimersAndDementias as float)/TotalDeaths)*100 as 'AlzPercentage', AgeRange
FROM SeventyPlusDeathCauses
WHERE Country like '%states%'
Order by Country

--countries deaths by alzheimers perc for 2019 (latest year)
SELECT Country, CAST(AlzheimersAndDementias as float)/TotalDeaths *100 as 'AlzPercentageOfDeaths'
FROM FiftyToSixtyNineDeathCauses
--omit null country codes since those rows represent duplicate or extranious country values
WHERE CountryCode is not null and Year  =  2019
--Group by Country, CountryCode
ORDER by AlzPercentageOfDeaths desc

--Global numbers (total cases by year and percentage of total deaths overall)
SELECT Year, Sum(AlzheimersAndDementias) as TotalAlzDeaths, SUM(CAST(AlzheimersAndDementias as float))/SUM(TotalDeaths)*100 as PercOfTotal
FROM FiftyToSixtyNineDeathCauses
WHERE CountryCode is not Null 
Group by Year
ORDER by Year desc


-- view column names
SELECT COLUMN_NAME, TABLE_NAME
FROM INFORMATION_SCHEMA.COLUMNS
--WHERE TABLE_NAME = 'FiveToFourteenDeathCauses'
ORDER BY COLUMN_NAME

--view deaths in ages 50-69 by country
SELECT Country, Count(*) As CountryCount
FROM FiftyToSixtyNineDeathCauses
--WHERE Country = 'United States'
Group by Country

--Use CTE and creat view of Alz rolling death percentages by age

Create View RollingAlzDeathPercByAge as 
WITH alzDeathPerc AS (
    SELECT fifty.Country as Country, fifty.Year as Year, fifty.AlzheimersAndDementias as fiftyTo69Total, fifty.TotalDeaths as fiftyto69Deaths,
    (CAST(fif.AlzheimersAndDementias as float)/NULLIF(fif.TotalDeaths, 0)) * 100 as AlzPer15ToFortyNine,
    (CAST(fifty.AlzheimersAndDementias as float)/NULLIF(fifty.TotalDeaths,0)) * 100 as AlzPer50To69,
    (CAST(sev.AlzheimersAndDementias as float)/NULLIF(sev.TotalDeaths,0)) * 100 as AlzPer70Plus
--OVER(partition by sev.Country order by sev.Year) 
--Avg(CAST(fif.AlzheimersAndDementias as float)/fif.TotalDeaths) OVER() as AlzRollingPerfifteenToForty
FROM FifteenToFortyNineDeathCauses fif
JOIN FiftyToSixtyNineDeathCauses fifty
    ON fifty.Country = fif.Country AND fifty.Year = fif.Year
Join SeventyPlusDeathCauses sev 
    ON fif.Country = sev.Country AND fif.Year = sev.Year
WHERE fif.CountryCode is not null AND fifty.Country IN ('United States', 'Afghanistan') 
)
SELECT Country, Year, fiftyTo69Total, fiftyto69Deaths, ROUND(AlzPer50To69, 2) as AlzPer50To69, 
ROUND(Avg(AlzPer50To69) OVER(partition by Country ORDER BY Year ROWS BETWEEN 3 Preceding AND Current ROW), 2) as RollingAvg50To69, 
ROUND(Avg(AlzPer70Plus) OVER(partition by Country ORDER BY Year ROWS BETWEEN 3 Preceding AND Current ROW), 2) as RollingAvg70Plus,
ROUND(Avg(AlzPer15ToFortyNine) OVER(partition by Country ORDER BY Year ROWS BETWEEN 3 Preceding AND Current ROW), 2) as RollingAvg15To49

FROM alzDeathPerc

SELECT (CAST(AlzheimersAndDementias as float)/TotalDeaths)*100
FROM SeventyPlusDeathCauses

--Create Temp table of nutrition averages by age (underAge5 doesnt have stats for 'Protein-energy malnutrition' (weird since it looks like it's often a childhood ailment))
DROP Table if exists #NutritionalDeathsRollingAvg
Create Table #NutritionalDeathsRollingAvg
(
Country nvarchar(255),
Year numeric,
fifteenTo49ProtEnergyDeaths int,
fifteenTo49NutDeaths int,
fifteenTo49TotalDeaths int,
NutritionalDeathPercfifteenTo49 int,
NutritionalDeathPercUnder5 int,
NutritionalDeathPerc5To14 int,
NutritionalDeathPerc50To69 int,
NutritionalDeathPerc70Plus int
)
Insert into #NutritionalDeathsRollingAvg
SELECT  fif.Country, fif.Year, fif.[Protein-energy malnutrition], fif.[Nutritional deficiencies], fif.TotalDeaths, Round((CAST((fif.[Protein-energy malnutrition]+ fif.[Nutritional deficiencies]) as float)/NULLIF(fif.TotalDeaths,0))*100, 2) as NutDefPercsev15ToFortyNine,
Round((CAST(u5.[Nutritional deficiencies] as float)/NULLIF(u5.TotalDeaths, 0))*100, 2) as NutDefPercU5,
Round((CAST((fiv14.[Protein-energy malnutrition]+ fiv14.[Nutritional deficiencies]) as float)/NULLIF(fiv14.TotalDeaths, 0))*100, 2) as NutDefPerc5ToFourteen,
Round((CAST((fifty.[Protein-energy malnutrition]+ fifty.[Nutritional deficiencies]) as float)/NULLIF(fifty.TotalDeaths,0))*100, 2) as NutDefPerc50ToSixtyNine,
Round((CAST((sev.[Protein-energy malnutrition]+ sev.[Nutritional deficiencies]) as float)/NULLIF(sev.TotalDeaths,0))*100, 2) as NutDefPercsev
FROM FifteenToFortyNineDeathCauses fif
Join UnderFiveDeathCauses u5 
    ON fif.Country = u5.Country AND fif.Year = u5.Year
Join FiveToFourteenDeathCauses fiv14 
    ON u5.Country = fiv14.Country AND u5.Year = fiv14.Year
JOIN FiftyToSixtyNineDeathCauses fifty
    ON fiv14.Country = fifty.Country AND fiv14.Year = fifty.Year
Join SeventyPlusDeathCauses sev 
    ON fifty.Country =sev.Country  AND fifty.Year = sev.Year
WHERE fif.CountryCode is not Null


SELECT Country, Year, fifteenTo49ProtEnergyDeaths,
fifteenTo49NutDeaths,
fifteenTo49TotalDeaths,
ROUND(Avg(NutritionalDeathPercfifteenTo49) OVER(partition by Country ORDER BY Year ROWS BETWEEN 3 Preceding AND Current ROW), 2) as RollingNutDeathPerc15To49,
ROUND(Avg(NutritionalDeathPercUnder5) OVER(partition by Country ORDER BY Year ROWS BETWEEN 3 Preceding AND Current ROW), 2) as RollingNutDeathPercUnder5,
ROUND(Avg(NutritionalDeathPerc5To14) OVER(partition by Country ORDER BY Year ROWS BETWEEN 3 Preceding AND Current ROW), 2) as RollingNutDeathPerc5To14,
ROUND(Avg(NutritionalDeathPerc50To69) OVER(partition by Country ORDER BY Year ROWS BETWEEN 3 Preceding AND Current ROW), 2) as RollingNutDeathPerc50To69,
ROUND(Avg(NutritionalDeathPerc70Plus) OVER(partition by Country ORDER BY Year ROWS BETWEEN 3 Preceding AND Current ROW), 2) as RollingNutDeathPerc70Plus
FROM #NutritionalDeathsRollingAvg

--Create CTE to use in view of rolling average of nutritional deaths (may use to determine correlation between nutrional issues and dementia)
Create View NutritionalDeathsRolling3yearAvg as
With NutritionalDeathsRollingAvg as(
SELECT  fif.Country as Country, fif.Year as Year, fif.[Protein-energy malnutrition] as fifteenTo49ProteinDefDeaths, fif.[Nutritional deficiencies] as fifteenTo49NutDeaths, fif.TotalDeaths as fifteenTo49DeathTotals, Round((CAST((fif.[Protein-energy malnutrition]+ fif.[Nutritional deficiencies]) as float)/NULLIF(fif.TotalDeaths,0))*100, 2) as NutDefPercsev15ToFortyNine,
Round((CAST(u5.[Nutritional deficiencies] as float)/NULLIF(u5.TotalDeaths, 0))*100, 2) as NutDefPercU5,
Round((CAST((fiv14.[Protein-energy malnutrition]+ fiv14.[Nutritional deficiencies]) as float)/NULLIF(fiv14.TotalDeaths, 0))*100, 2) as NutDefPerc5ToFourteen,
Round((CAST((fifty.[Protein-energy malnutrition]+ fifty.[Nutritional deficiencies]) as float)/NULLIF(fifty.TotalDeaths,0))*100, 2) as NutDefPerc50ToSixtyNine,
Round((CAST((sev.[Protein-energy malnutrition]+ sev.[Nutritional deficiencies]) as float)/NULLIF(sev.TotalDeaths,0))*100, 2) as NutDefPercsev
FROM FifteenToFortyNineDeathCauses fif
Join UnderFiveDeathCauses u5 
    ON fif.Country = u5.Country AND fif.Year = u5.Year
Join FiveToFourteenDeathCauses fiv14 
    ON u5.Country = fiv14.Country AND u5.Year = fiv14.Year
JOIN FiftyToSixtyNineDeathCauses fifty
    ON fiv14.Country = fifty.Country AND fiv14.Year = fifty.Year
Join SeventyPlusDeathCauses sev 
    ON fifty.Country =sev.Country  AND fifty.Year = sev.Year
WHERE fif.CountryCode is not Null
)
SELECT Country, Year, fifteenTo49ProteinDefDeaths,
fifteenTo49NutDeaths,
fifteenTo49DeathTotals,
ROUND(Avg(NutDefPercsev15ToFortyNine) OVER(partition by Country ORDER BY Year ROWS BETWEEN 3 Preceding AND Current ROW), 2) as RollingNutDeathPerc15To49,
ROUND(Avg(NutDefPercU5) OVER(partition by Country ORDER BY Year ROWS BETWEEN 3 Preceding AND Current ROW), 2) as RollingNutDeathPercUnder5,
ROUND(Avg(NutDefPerc5ToFourteen) OVER(partition by Country ORDER BY Year ROWS BETWEEN 3 Preceding AND Current ROW), 2) as RollingNutDeathPerc5To14,
ROUND(Avg(NutDefPerc50ToSixtyNine) OVER(partition by Country ORDER BY Year ROWS BETWEEN 3 Preceding AND Current ROW), 2) as RollingNutDeathPerc50To69,
ROUND(Avg(NutDefPercsev) OVER(partition by Country ORDER BY Year ROWS BETWEEN 3 Preceding AND Current ROW), 2) as RollingNutDeathPerc70Plus
FROM NutritionalDeathsRollingAvg

Select Sum(AlzheimersAndDementias), sum(TotalDeaths)

SELECT (Cast(sum(AlzheimersAndDementias) as float)/sum(TotalDeaths))*100 as alzDeathPerc
from FifteenToFortyNineDeathCauses
WHERE CountryCode is not null


--Show alz death perc by country and year compared to world alz death per by year
--show each country's contribution/percentage to total alzheimers deaths by year
Create View AlzDeathPercByYearAndCountry as
With DeathTotals as (
SELECT fif.Country as Country, fif.Year as Year, fif.AlzheimersAndDementias as fifAlz, fifty.AlzheimersAndDementias as fiftyAlz, sev.AlzheimersAndDementias as sevAlz, (sum(fif.TotalDeaths) over(partition by fif.Year Order by fif.Year)) + (sum(u5.TotalDeaths) over(partition by u5.Year)) + (sum(fiv14.TotalDeaths)over(partition by fiv14.Year)) + (sum(fifty.TotalDeaths)over(partition by fifty.Year)) + (sum(sev.TotalDeaths)over(partition by sev.Year)) as TotalWorldDeaths,
(sum(fif.AlzheimersAndDementias) over(partition by fif.Year)) + (sum(fifty.AlzheimersAndDementias)over(partition by fifty.Year)) + (sum(sev.AlzheimersAndDementias)over(partition by sev.Year)) as TotalWorldAlzAndDemDeaths

FROM FifteenToFortyNineDeathCauses fif
Join UnderFiveDeathCauses u5 
    ON fif.Country = u5.Country AND fif.Year = u5.Year
Join FiveToFourteenDeathCauses fiv14 
    ON u5.Country = fiv14.Country AND u5.Year = fiv14.Year
JOIN FiftyToSixtyNineDeathCauses fifty
    ON fiv14.Country = fifty.Country AND fiv14.Year = fifty.Year
Join SeventyPlusDeathCauses sev 
    ON fifty.Country =sev.Country  AND fifty.Year = sev.Year
WHERE fif.CountryCode is not Null
)
SELECT Country, Year, fifAlz, fiftyAlz, sevAlz,
Round((cast(fifAlz as float)/TotalWorldAlzAndDemDeaths)*100, 2) as PercTotalAlzDeaths_15To49, Round((cast(fiftyAlz as float)/TotalWorldAlzAndDemDeaths)*100, 2) as PercTotalAlzDeaths_50To69, Round((cast(sevAlz as float)/TotalWorldAlzAndDemDeaths)*100, 2) as TotalPercAlzDeaths_70Plus,
Round((cast(TotalWorldAlzAndDemDeaths as float)/NULLIF(TotalWorldDeaths,0))*100, 2) as TotalAlzDeathPercOfTotalByYear
FROM DeathTotals
--Order by Year, Country

SELECT Country, CountryCode, Year, TotalDeaths, AgeRange
FROM FifteenToFortyNineDeathCauses
WHERE TotalDeaths=0




SELECT  fif.Country, fif.Year, 
fif.[Protein-energy malnutrition], 
fif.[Nutritional deficiencies], 
fif.TotalDeaths
--fif.Country, fif.Year, fif.[Protein-energy malnutrition], fif.[Nutritional deficiencies], fif.TotalDeaths, Round((CAST((fif.[Protein-energy malnutrition]+ fif.[Nutritional deficiencies]) as float)/fif.TotalDeaths)*100, 2) as NutDefPercsev15ToForty,
--ROUND((CAST(u5.[Nutritional deficiencies] as float)/u5.TotalDeaths)*100, 2) as NutDefPercU5,
--ROUND((CAST((fiv14.[Protein-energy malnutrition]+ fiv14.[Nutritional deficiencies]) as float)/fiv14.TotalDeaths)*100, 2) as NutDefPerc5ToFourteen,
--ROUND((CAST((fifty.[Protein-energy malnutrition] + fifty.[Nutritional deficiencies]) as float)/fifty.TotalDeaths) *100, 2) as NutDefPerc50ToSixtyNine,
--Round((CAST((sev.[Protein-energy malnutrition]+ sev.[Nutritional deficiencies]) as float)/sev.TotalDeaths)*100, 2) as NutDefPercsev
FROM FifteenToFortyNineDeathCauses fif
Join UnderFiveDeathCauses u5 
    ON fif.Country = u5.Country AND fif.Year = u5.Year
Join FiveToFourteenDeathCauses fiv14 
    ON u5.Country = fiv14.Country AND u5.Year = fiv14.Year
JOIN FiftyToSixtyNineDeathCauses fifty
    ON fiv14.Country = fifty.Country AND fiv14.Year = fifty.Year
Join SeventyPlusDeathCauses sev 
    ON fifty.Country =sev.Country  AND fifty.Year = sev.Year
WHERE fif.CountryCode is not Null
--ORDER By fif.Year
Create view totalAlzByYear as
SELECT fif.Year, sum(fif.AlzheimersAndDementias) AlzDeaths15To49, sum(fifty.AlzheimersAndDementias) AlzDeaths50To69, sum(sev.AlzheimersAndDementias) AlzDeathsOver70 
From FifteenToFortyNineDeathCauses fif
join FiftyToSixtyNineDeathCauses fifty
on fif.Country = fifty.Country AND fif.Year = fifty.Year
join SeventyPlusDeathCauses sev 
on fif.Country = sev.Country AND fif.Year = sev.Year
Where fif.CountryCode is not Null 
Group by fif.Year

Create view AlzPerOfTotal15Plus as
SELECT fif.Country, fif.Year, (CAST((fif.AlzheimersAndDementias + fifty.AlzheimersAndDementias + sev.AlzheimersAndDementias) as float)/(fif.TotalDeaths + fifty.TotalDeaths + sev.TotalDeaths)) * 100 as percOfCountryTotalDeaths, (fif.AlzheimersAndDementias + fifty.AlzheimersAndDementias + sev.AlzheimersAndDementias) as TotalAlzDemAllAgesbyCountry
From FifteenToFortyNineDeathCauses fif
join FiftyToSixtyNineDeathCauses fifty
on fif.Country = fifty.Country AND fif.Year = fifty.Year
join SeventyPlusDeathCauses sev 
on fif.Country = sev.Country AND fif.Year = sev.Year
Where fif.CountryCode is not Null 
