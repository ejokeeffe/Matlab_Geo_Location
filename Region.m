%> @file Region.m
%
%> @brief 
%
%> @authors Eoin O'Keeffe (eoin.okeeffe.09@ucl.ac.uk)
%
%> @date initiated: 11/05/2011
%> @data version 1.1: 15/07/2011
%> <br /> <i>Version 1.2</i>: 6/12/2012
%> <br /><i>Version 1.3</i>: 26/01/2013
%
%> @version 
%> 1.0 Basic class to get all the regions as well as inserting new
%> regionGroups.
%> <br />version 1.1: getName extended to allow an array of ids to be
%> passed
%> <br /><i>Version 1.2</i>: resolveToRegions altered so it loops through
%> the unique ctries not every one so it avoids repeats
%> <br />,i>Version 1.3</i>: Added function saveToExcel which save the
%>currently select region to an excel file - countryname, countrycode,
%> regionname, regioncode. Added primarily for use with glotram
%>
%> @section intro Method
%>
%
%>@attention
%>@todo Add deleteRegionGroup function to delete and region group and
%>cascade this down
classdef Region < handle
      properties(Constant)
    %> Constants used to access individual cols of properties
    Name =2
    ID = 1
    RegionGroupID = 3
  end
   properties 
       %> currentRegionGroup [ID Name]
       currentRegionGroup 
       %> regions [ID Name RegionGroupID]
       regions
       %> countries [array of countries using same column indexes as
       %> countries, but with an additional column at the end with the id of
       %> the parent region
       countries
       
   end
   methods
    % ======================================================================
    %> @brief Set the current region property. Once this is set, get all
    %> the child countries for that group
    %>
    %> @param obj Instance of class
    %> @param regionName string of region name to set the current
    %> regiongroup to
    %> User has to pass a string of the name of the regionGroup to use
    
    % =====================================================================       
       function setCurrentRegionGroup(obj,regionName)
           grps = Region.getRegionGroups;
           %Set the current region from the full list of region groups
           obj.currentRegionGroup = Useful.FindCellInCellSimple(grps(:,Region.Name),...
               {regionName});
           obj.currentRegionGroup = grps(obj.currentRegionGroup,:);
           %Now get all theg current regions based on the selected
           %regiongroup
           obj.getCurrentRegions;
            
       end
       % ======================================================================
    %> @brief Funciton to load the regions - called from the set
    %> currentRegionGroup property
    %>
    %> User has to pass a string of the name of the regionGroup to use
    
    % =====================================================================   
    function getCurrentRegions(obj)
        db=DataBasePG();
            db.db = 'Router';
            obj.regions = db.executeQuery(['Select * from "Region" where "RegionGroupID"='...
                Useful.Val2Str(obj.currentRegionGroup(:,Region.ID))]);
    end %getRegions
% ======================================================================
    %> @brief Function that gets all the current countries associated iwtht
    %> the current regions. Loop through each of our region and load the
    %> associated country
    %>@param obj
    %>@retval ctries the array of countries. This can be accessed later
    %>using obj.countries
    % =====================================================================
    function [ctries] = getCurrentCountries(obj)
        %Lets load up all the countries first, we can strip out the
        %countries we don't want after
        obj.countries = Country.getCountries();
        %Add extra field to hold the region
        obj.countries = [obj.countries cell(length(obj.countries),1)];
        db=DataBasePG();
           db.db = 'Router';
           for i=1:size(obj.regions,1)
               tmpCountries = db.executeQuery(['Select * from "RegionCountryLink" where "RegionID"='...
                Useful.Val2Str(obj.regions(i,Region.ID))]);
                %tmpCountries should now be a cell array of [ID RegionID CountryCode]
                %so lets loop through it and drop in the RegionID in the
                %associated COuntryCOde
                for j=1:size(tmpCountries,1)
                    %disp(['i=' num2str(i) ' and j=' num2str(j)]);
                    regionID = tmpCountries(j,2);
                    ctryIndx = cell2mat(obj.countries(:,Country.Code))...
                        ==cell2mat(tmpCountries(j,3));
                    obj.countries(ctryIndx,end) = regionID;
                end %for j
                
           end %for i
            %Now we want to strip out any countries that have no
                %associated region
                obj.countries(cellfun(@isempty,obj.countries(:,end)),:)=[];
                ctries = obj.countries;
    end %getRegions
   % ======================================================================
    %> @brief Function that resolves all the countries passed 
    %>  to their regions
    %>@param obj
    %>@param ctries vector of country codes
    %>@retval rgns matrx  with region ids whose correcponding indexes
    %> align with the tr_te array of country pairs
    % =====================================================================
    function [rgns] = resolveToRegions(obj,ctries)
       %Get the countries
       ctriesCurrent = obj.getCurrentCountries; 
       
       %get unique countries first, no point looping through if there are
       %repeats
       [uniqCtries,~,ctryIndxs] = unique(ctries);
       
       rgns = zeros(size(uniqCtries));
       for i=1:size(uniqCtries,1)
           tmp = find(cell2mat(ctriesCurrent(:,Country.Code))==uniqCtries(i,1));
           if isempty(tmp)
%                d = dbstack;
%                %Add log to say we couldn't find it
%                Logging.addLog('Country has no associated region',['Country: '...
%                    Useful.Val2Str(Country.getName({ctries(i,1)},Country.Code)) ' not found in '...
%                    'current countries'],d(1).file,d(1).name,num2str(d(1).line),Logging.Verbose);
           else
               rgns(i) = cell2mat(ctriesCurrent(tmp,end));
           end %if
       end %for i
       %[~,ctryIndxs] = ismember(ctries,uniqCtries);
       rgns = rgns(ctryIndxs);
    end %function resolveToRegions
    function addCountryToRegion(obj,region,countryCode)
            for i=1:size(region,1) 
                if strcmp(class(region(i)),'cell')
                    for j=1:size(obj.regions,1)
                        if strcmp(char(region(i)),obj.regions(j,2))
                            tmp = cell2mat(obj.regions(j,1));
                        end %if
                    end %for j
                else 
                    tmp= region(i); 
                end %if
                db = DataBasePG;
                db.db = 'Router';
                db.setRow([{tmp} {countryCode(i)}],[{'"ID"'} {'"RegionID"'} {'"CountryCode"'}],'"RegionCountryLink"');;
            end %for i
        end %function addCountryToRegion
        
        %==================================================================
        %> @brief outputs teh regions and countries to excel file. The name
        %> of the file will be the name of the regiongroup
        %> 
        %> @param obj
        %> @param folder The folder to which to save the results
        %>
        function saveToExcel(obj,folder)
            output = [obj.countries(:,Country.Code) obj.countries(:,Country.Name) ...
                obj.countries(:,end)];
            [~,indxs] = ismember(cell2mat(obj.countries(:,end)),...
                cell2mat(obj.regions(:,Region.ID)));
            
            output = [output obj.regions(indxs,Region.Name)];
            output = [[{'UN Country Code'},{'Country Name'},{'Region ID'},...
                {'Region Name'}];output];
            filename = [folder '\' obj.currentRegionGroup{Region.Name} '.xls'];
            
            xlswrite(filename,output,'regions');
            
        end %function saveToExcel
   end %no-static methods
methods (Access=public, Static=true)
    % ======================================================================
    %> @brief Get the full list of region groups
    %>
    %> This method is public and static
    %> @retval x list of regions in the form [ID Name] 
    %> NOTE: Access values using the constant properties
    % =====================================================================
    function [x] = getRegionGroups()
        persistent regionGroups;
        if isempty(regionGroups)
            db=DataBasePG();
            db.db = 'Router';
            regionGroups = db.getAll('RegionGroup');
            %  [ID(1) Code(2) Name(3) Fullname(4) Abbr(5) Comments(6)
            %  ISO2(7) EndYear(8) ISO3(9) StartYear(11)]
        end %if
        x = regionGroups;
    end %function getCountries
    % ======================================================================
    %> @brief Get the full list of region groups
    %>
    %> This method is public and static
    %> @retval x list of regions in the form [ID Name] 
    %> NOTE: Access values using the constant properties
    % =====================================================================
    function [x] = getRegions()
        persistent regions;
        if isempty(regions)
            db=DataBasePG();
            db.db = 'Router';
            regions = db.getAll('Region');
            %  [ID Name RegionGroupID]
        end %if
        x = regions;
    end %function getRegions
        % ======================================================================
    %> @brief Gets the names of the reigons based on the IDs
    %>
    %> @param id Region ID as called off in the region table
    %> @retval name the name of the region
    % =====================================================================
        function [name] = getNames(id)
            %first get the country list
            rgns = Region.getRegions;
            name = cell(size(id,1),1);
            %Edited EO'k so we can take in an array of ids
            for i=1:size(id,1)
                %Check to see if the country exists in the db
                tmp_ind = cell2mat(rgns(:,1))==id(i,1);
                tmpName = [];
                if sum(tmp_ind,1)==0
                   %tmpName = -1;
                   %Add log to say that we couldn't find this country
                    d = dbstack;
                     %More than one entry so lets log it
%                      Logging.addLog('Corresponding region for country not found',...
%                          ['Country name: ' char(Country.getCodes(id(i,1),...
%                          Country.Code,Country.Name))],d(1).file,...
%                          d(1).name,d(1).line,Logging.Verbose);
                else
                    tmpName = rgns(tmp_ind,Region.Name);
                end
                name(i,1) = tmpName;
            end %for i
            
        end
       % ====================================================
       %> @brief inserts a region grouping. All regionNames will be
       %> inserted as new even if they are duplicated names, as they will be
       %> uniquely associated with a particular regionGroup
    %>Example coe to read in from spreadsheet and run this function:
    %> db = DataBaseXls
%> db.root = 'D:\PHD\Modelling\Data\Location\Interop'
%> db.db = '\Annex1Countries.xls'
%> tmp = db.getAll('Sheet1');
%> tmp2 = cellfun(@Useful.Val2Str,tmp(:,3),'UniformOutput',false)
%> tmp2= cellfun(@(x) ~strcmp(x,'NaN'),tmp2);
%> tmp3 = tmp(tmp2,:)
%> Region.insertRegionGroup('IPCCAnnex',[tmp3(:,3) tmp3(:,1)])
%
    %> @param name name of regionGroup
    %> @param rgnAndCountry cell array in form [regionName CountryCode] -
    %> the countrycode is the UN country code
    % =====================================================================
    function insertRegionGroup(name,rgnAndCountry)
        %First ass the regiongroup and get its id
        db = DataBasePG;
        db.db = 'Router';
        rgnGrpID = db.setRow(name,{'"ID"' '"Name"'},'"RegionGroup"');
        disp([Useful.Val2Str(name) ' added to RegionGroup table. ID = '...
            num2str(rgnGrpID)]);
        %Now insert a new region for each of the unique region names
        rgns = unique(cellfun(@Useful.Val2Str,rgnAndCountry(:,1),'UniformOutput',false));
        rgns_id = zeros(size(rgns,1));
        for i=1:size(rgns,1)
            %Insert row for each of the regions
            rgns_id(i,1) = db.setRow([rgns(i,1) rgnGrpID],...
                {'"ID"' '"Name"' '"RegionGroupID"'}, '"Region"');
            disp([Useful.Val2Str(rgns(i,1)) ' added to RegionGroupID table']);
        end %for i
        %Now insert a regionCountryLink for each of the countries
        for i=1:size(rgnAndCountry,1)
            %Insert row for each of the country instances
            tmp_rgnID = Useful.FindCellInCellSimple(rgns,rgnAndCountry(i,1));
            tmp_rgnID = rgns_id(tmp_rgnID);
            db.setRow([{tmp_rgnID} rgnAndCountry(i,2)],...
                {'"ID"' '"RegionID"' '"CountryCode"'},'"RegionCountryLink"');
            disp(['COuntry ID: ' Useful.Val2Str(rgnAndCountry(i,2))...
                ' added to RegionCountryLink table']);
        end %for i
    end %function insertRegionGroup
    % ====================================================
       %> @brief Deletes a regionGroup and cascade the delete through the
       %Region and RegionCountryLink table
    %>
    %> @param name name of regionGroup
    % =====================================================================
    function deleteRegionGroup(name)
        %Get id of regionGroup
         db = DataBasePG;
        db.db = 'Router';
         RGID = db.executeQuery(['Select "ID" from "RegionGroup" where "Name"='''...
                name '''']);
           
            %Now delte the regionGroup
            db.executeQuery(['Delete from "RegionGroup" where "ID"='...
                Useful.Val2Str(RGID)]);
            %Now get all the region ids where the RegionGroupID = RGID
            RID = db.executeQuery(['Select "ID" from "Region" where "RegionGroupID"='...
                Useful.Val2Str(RGID)]);
            %Now delete these regions
            db.executeQuery(['Delete from "Region" where "RegionGroupID"='...
                Useful.Val2Str(RGID)]);
            %Now cycle through each of the regions and delete the
            %associated link
            for i=1:size(RID,1)
                db.executeQuery(['Delete from "RegionCountryLink" where "RegionID"='...
                Useful.Val2Str(RID(i,1))]);
            end %for i
            
    end %function deleteRegionGroup
        function [rgnDist] = getDistance(ports,rtes)
            %Check if repPorts is set, if not then use average of all ports
            %First, get unique list of countries
            ctries = unique(ports(:,2));
            %make sure there are no zeros - these indicate the world
            ctries = ctries(ctries(:,1)>0,:);
            %INstantiate dist matrix [ctryID PartnerCtryID dist] 
            ctryDist = zeros(size(ctries,1)*(size(ctries,1)-1),3);
            %loop through ctries and get dist
            for i=1:size(ctries,1)
                homeCtry = ctries(i,1);
                for j=1:size(ctries,1)
                    %First check to make sure it isn't the same country
                    %we're matching to
                    destCtry = ctries(j,1);
                    if destCtry~=homeCtry
                        %Get all ports for homeCtry and all the ports for
                        %destCtry
                        homePorts = ports(ports(:,2)==homeCtry,:);
                        destPorts = ports(ports(:,2)==destCtry,:);
                        tmpDist = zeros(size(homePorts,1)*size(destPorts,1),1);
                        for k=1:size(homePorts,1)
                            for l=1:size(destPorts,1)
                                tmpDist((k-1)*2+l,1) = ...
                                    rtes.getPortsDistance(homePorts(k,1),destPorts(l,1));
                            end %for l
                        end %for k
                        %Get next empty row
                        tmpInd = find(ctryDist(:,2)==0);
                        %Check to see if tmpDist is NaN, don't add if it is
                        if ~isnan(tmpDist)
                            
                            ctryDist(tmpInd(1,1),:) = [homeCtry destCtry mean(tmpDist)];
                        end
                    end %if
                end %for j
            end %for i
            %strip off zero rows at end
            tmpInd = find(ctryDist(:,2)==0);
            ctryDist = ctryDist(1:tmpInd(1,1)-1,:);
        end%getDistance
        
        
end %static methods
    
end

