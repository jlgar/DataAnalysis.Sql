--Load Nashville Housing Data into SQL
DROP TABLE If EXISTS NashvilleHousingTest

Create Table NashvilleHousingTest (
    UniqueId int,
    ParcelID varchar(255),
    LandUse varchar(255),
    PropertyAddress varchar(255),
    SaleDate varchar(255),
    SalePrice varchar(255),
    LegalReference varchar(255),
    SoldAsVacant varchar(255),
    OwnerName varchar(255), 
    OwnerAddress varchar(255),
    Acreage float,
    TaxDistrict varchar(255),
    LandValue float,
    BuildingValue float,
    TotalValue float,
    YearBuilt float,
    Bedroom float,
    FullBath float,
    HalfBath float,
    ) ;

--insert csv into sql dataset
BULK INSERT CauseOfDeath.dbo.NashvilleHousingTest
FROM '/NashvilleHousing.csv'
WITH ( FORMAT = 'CSV');

SELECT *
FROM CauseOfDeath.dbo.NashvilleHousingTest

--Take a look at the data
select *
From NashvilleHousingTest

--Standardize Date Format
Select SaleDate, CONVERT(Date, SaleDate) 
From NashvilleHousingTest

Update NashvilleHousingTest
Set SaleDate = Convert(Date, SaleDate)

--populate missing Property Address 

select *
From NashvilleHousingTest
Where PropertyAddress is null
order by ParcelID

Select a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, ISNULL(a.PropertyAddress,b.PropertyAddress)
From NashvilleHousingTest a 
JOIN NashvilleHousingTest b 
    on a.ParcelID = b.ParcelID
    And a.UniqueID <> b.UniqueID
Where a.PropertyAddress is null

Update a
SET PropertyAddress = ISNULL(a.PropertyAddress, b.PropertyAddress)
From NashvilleHousingTest a 
JOIN NashvilleHousingTest b 
    on a.ParcelID = b.ParcelID
    And a.UniqueID <> b.UniqueID
Where a.PropertyAddress is null

-- Break out Address into Individual Columns (Address, City, State)
select PropertyAddress
From NashvilleHousingTest

Alter Table NashvilleHousingTest
Add PropertyStreetAddress NVarchar(255);

Update NashvilleHousingTest
SET PropertyStreetAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) -1)

Alter Table NashvilleHousingTest
Add PropertyCity NVarchar(255);

Update NashvilleHousingTest
SET PropertyCity = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1, LEN(PropertyAddress))

Select PropertyCity, PropertyStreetAddress
From NashvilleHousingTest

--Split Owner Address
select OwnerAddress
From NashvilleHousingTest

Alter Table NashvilleHousingTest
Add OwnerStreetAddress NVarchar(255);

Update NashvilleHousingTest
SET OwnerStreetAddress = Parsename(REPLACE(OwnerAddress, ',','.'), 3)

Alter Table NashvilleHousingTest
Add OwnerCity NVarchar(255);

Update NashvilleHousingTest
SET OwnerCity = Parsename(REPLACE(OwnerAddress, ',','.'), 2)

Alter Table NashvilleHousingTest
Add OwnerState NVarchar(255);

Update NashvilleHousingTest
SET OwnerState = Parsename(REPLACE(OwnerAddress, ',','.'), 1)

Select * 
From NashvilleHousingTest

--Chany Y and N to Yes and No in 'Sold as Vacant' field

Select Distinct(SoldAsVacant), Count(SoldAsVacant)
From NashvilleHousingTest
Group by SoldAsVacant
Order by 2

Select Count(SoldAsVacant)
, CASE When SoldAsVacant = 'Y' Then 'Yes'
       When SoldAsVacant = 'N' Then 'No'
       Else SoldAsVacant
       End
From NashvilleHousingTest
Group by SoldAsVacant

Update NashvilleHousingTest
Set SoldAsVacant = CASE When SoldAsVacant = 'Y' Then 'Yes'
       When SoldAsVacant = 'N' Then 'No'
       Else SoldAsVacant
       End

--Remove Duplicates
With RowNumCTE AS(
Select *, 
    ROW_NUMBER() OVER (
        Partition by ParcelID, 
                    PropertyAddress,
                    SalePrice,
                    SaleDate,
                    LegalReference
                    ORDER BY UniqueID
                    ) row_num

From NashvilleHousingTest)

Select *
Delete
From RowNumCTE
WHERE row_num > 1


--Delete Unused Columns
Select * 
From NashvilleHousingTest

ALTER Table NashvilleHousingTest
Drop Column OwnerAddress, TaxDistrict, PropertyAddress, SaleDate

