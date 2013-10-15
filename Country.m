%> @file Country.m
%> @brief Country class used to store details of a country
%> @section matlabComments Details
%> @authors Eoin O'Keeffe (eoin.okeeffe.09@ucl.ac.uk)
%> @date initiated: 08/02/2010
%> @date version 1.1: 10/03/2011
%> <br /> version 1.1<br />: 24/10/2011
%> <br /> <i>Version 1.3</i>: 6/12/2012
%> <br /><i> Version 1.4</i>: 21/01/2013
%>
%> @version 
%> 1.0 Static functions set up
%> <br />1.1 getCode function extended so it user can select which index to
%> return, it defaults to the country code if only two vars are passed
%> table
%> <br /> Version 1.2: Extended getCodes so it incorporates the match files
%> @section intro Method
%> Exposes static functions for resolving the countries. Eg. You have a UN
%> country code and want to find the ISO 2 digit code for it.
%> <br /> <i> Version 1.3</i>: GetCodes altered so it matches unique
%> country names or codes rather than looping through each individually.
%> Speeds things up a good bit if a large set is passed. Also for 
%> getCountryNameMatches I did a standard replacement and rematch for
%> obvious abbreviations (eg Territory changed to Terr.)
%> <br /><i> Version 1.4</i>: getFuzzyMatches added
%>
%> @attention
%> @todo 
classdef Country
    
      properties(Constant)
    ISO2 =7
    ISO3=9
    Code=2
    Name =3
      end
  properties
      %> ID through which the parent region is referenced
     regionID 
     
  end
    methods (Access=public, Static=true)
        function insertFuzzyMatch(ctry,ctryCode)
            db = DataBasePG;
            db.db = 'Router';
            ctry = {strrep(ctry,'''','''''')};
            ctryDBName = db.executeQuery(sprintf(['select "Name" from "ComtradeCountryCodes"'...
                ' where "Cty Code" = %d'],ctryCode));
            db.executeQuery(sprintf('Insert into "CountryFuzzyMatch" values (''%s'',''%s'',%d)',...
                char(ctry),char(ctryDBName),ctryCode));
        end %function insertFuzzyMatch
    % ======================================================================
    %> @brief Get the full list of countries
    %>
    %> This method is public and static
    %> @retval x list of countries in form [ID(1) Code(2) Name(3) Fullname(4) Abbr(5) Comments(6)
    %>  ISO2(7) EndYear(8) ISO3(9) StartYear(11)]. 
    %> NOTE: Access values using the constant properties
    % =====================================================================
    function [x] = getCountries()
        persistent countries;
        if isempty(countries)
            db=DataBasePG();
            db.db = 'Router';
            %db = DataBaseXls;
            %db.root = '\\Vboxsvr\phd\Modelling\Data\Location\Interop';
            %db.db = '\ComtradeCountryCodes.xlsx';
            %countries = db.getAll('ComtradeCountryCodes');
            countries = ...
                db.executeQuery('select * from "ComtradeCountryCodes"  where "End Valid Year" > 2013');
            %  [ID(1) Code(2) Name(3) Fullname(4) Abbr(5) Comments(6)
            %  ISO2(7) EndYear(8) ISO3(9) StartYear(11)]
        end %if
        x = countries;
    end %function getCountries
  
        % ======================================================================
    %> @brief Gets the name of the country based on some identifier
    %>
    %> @param code This is the identifier
    %> @param enum this is the type of identifier - see constant properties
    %> above
    %> @retval name the name of the country
    % =====================================================================
        function [name] = getName(code,enum)
            %first get the country list
            countries = Country.getCountries;
            %Check to see if the country exists in the db
            tmp_ind = Useful.FindCellInCellSimple(countries(:,enum),code);
            if tmp_ind==0
               name = -1;
               %Add log to say that we couldn't find this country
               
            else
                name = countries(tmp_ind,Country.Name);
            end
            
        end
         % ======================================================================
    %> @brief Gets selected index, default country code, for a passed
    %> identifier
    %>
    %> @param code This is the identifier
    %> @param enum this is the type of identifier - see constant properties
    %> above
    %> @param returncode the index of the element to return, defaults to
    %> country code
    %> @retval code the name of the country
    % =====================================================================
        function [code] = getCode(ref,enum,returncode)
            %=========================================================
            %Edited EOK 10/03/2011
            %check if three vars are passed, if yes, then get index of
            %element to return otherwise return the country code
            if nargin ==2 
                returncode = Country.Code;
            end
            %========================================================
            %first get the country list
            countries = Country.getCountries;
            %Check to see if the country exists in the db
            ref= strrep(Useful.Val2Str(ref),'Republic','Rep.');
            ref = strrep(ref,'Democratic','Dem.');
            ref = strrep(ref,'Islands','Isds');
            ref = strrep(ref,'British','Br.');
            ref = strrep(ref,'United States of America','USA');
            ref = strrep(ref,'Venezuela (Bolivarian Republic of)','Venezuela');
            ref = {ref};
            tmp_ind = Useful.FindCellInCellSimple(countries(:,enum),ref);
            if tmp_ind == 0
               code= -1;
               %Add log to say that we couldn't find this country
%                Logging.addLog([Useful.Val2Str(ref) ' not found!'],...
%                    'Couldnt find this country in our countries db','Commodities',...
%                    'getCode','68');
            else
                
                code = cell2mat(countries(tmp_ind,returncode));
            end
            
        end %function getCode
    % ======================================================================
    %> @brief Gets all codes for a list of references
    %>
    %> @param ref the vector containing the reference codes
    %> @param enum the type of identifier
    %> @param returncode
    %> @patam fuzzyMatch [optional] if set to 1, then looks up missing
    %> matched in the match excel files (default is 0)
    %> @retval codes vector containing all the codes corresponding to the 
    %> refs passed in
    % =====================================================================
        function [codes] = getCodes(ref,enum,returncode,fuzzyMatch)
            
            %=========================================================
            %Edited EOK 14/03/2011
            %check if three vars are passed, if yes, then get index of
            %element to return otherwise return the country code
            if nargin ==2 
                returncode = Country.Code;
                fuzzyMatch = 0;
            elseif nargin ==3
                fuzzyMatch = 0;
            end
            %========================================================
            if returncode == Country.Code
                
                % don't loop through all of ref. pick out the unique values
                % loop through them and then reassign
                uniqRefs = unique(ref);
                uniqCodes = zeros(size(uniqRefs));
                for i= 1:size(uniqRefs,1)
                    uniqCodes(i) = Country.getCode(uniqRefs(i),enum,returncode);
                end %for i
                %now reassign
                [~,codesIndxs] = ismember(ref,uniqRefs);
                codes = uniqCodes(codesIndxs);
            else
                % don't loop through all of ref. pick out the unique values
                % loop through them and then reassign
                uniqRefs = unique(ref);
                uniqCodes = cell(size(uniqRefs));
                for i= 1:size(uniqRefs,1)
                    uniqCodes(i) = {Country.getCode(uniqRefs(i),enum,returncode)};
                end %for i
                
                %now reassign
                [~,codesIndxs] = ismember(ref,uniqRefs);
                codes = uniqCodes(codesIndxs);
            end
            % if fuzzyMatch is 1 then check if anything unmatched and run
            % getCountryNameMatches on it
            if fuzzyMatch == 1 && enum == Country.Name
                missingIndxs = ismember(codes,-1);
                missing = ref(missingIndxs);
                if ~isempty(missing)
                    uniqMissing = unique(missing);
                    codesUniqMissing = Country.getCountryNameMatches(uniqMissing);
                    [~,uniqIndxs] = ismember(missing,uniqMissing);
                    missing = codesUniqMissing(uniqIndxs);
                    %now match these again
                    if returncode == Country.Code
                        missingCodes = zeros(size(missing,1),1);
                        for i= 1:size(missing,1)
                            missingCodes(i) = Country.getCode(missing(i),enum,returncode);
                        end %for i
                    else
                        missingCodes = cell(size(ref,1),1);
                        for i= 1:size(missing,1)
                            missingCodes(i) = {Country.getCode(missing(i),enum,returncode)};
                        end %for i
                    end
                    %drop these results into codes
                    codes(missingIndxs) = missingCodes;
                end %if
            end %if
            
        end %function getCodes

        % ======================================================================
        %> @brief getDistance gets distnace between country based on
        %> average distance between their associated ports
        %>
        %> @param ports vector of ports and associated countries. If more
        %> than one port is given for a country, the average distance is used
        %> [portID countryID]
        %> @param rtes instance of Route object storing the routes we use
        %> @retval ctryDist [homeCtryID destCtryID dist]
        % =====================================================================
        function [ctryDist] = getDistance(ports,rtes)
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
        end
        
        %==================================================================
        %> brief get country fuzzy name matches
        %>
        %> @retval fuzzyMatches dataset .match,.dbName,.ctryCode
        function [fuzzyMatches] = getFuzzyNames()
            db = DataBasePG;
            db.db = 'Router';
            data = db.executeQuery(['select "SourceName","dbName","UNCountryCode" from '...
                ' "CountryFuzzyMatch"']);
            fuzzyMatches = dataset;
            fuzzyMatches.match = data(:,1);
            fuzzyMatches.dbName = data(:,2);
            fuzzyMatches.ctryCode = cell2mat(data(:,3));
        end %getFuzzyNames
    end
    methods (Access=public)
                function [region] = getRegion(ref,enum)
            %first get the country list
            countries = Country.getCountries;
            regions = Country.getRegions;
            %Check to see if the country exists in the db
            tmp_ind = Useful.FindCellInCellSimple(countries(:,enum),{ref});
            if tmp_ind==0
               region = {-1};
               %Add log to say that we couldn't find this country
               
            else
                %Now get the region
                region = regions(cell2mat(regions(:,2))==cell2mat(countries(tmp_ind,Country.Code)),4);
            end
        end %function getRegion
    end %methods
    methods(Access=private,Static = true)
        % ======================================================================
        %> @brief getCountryNameMatches get amtch from database table
        %>
        %> @param unmatched name(s) of country that is unmatched
        %> @retval replace new name for country that would have match in
        %> the database
        % =====================================================================
        function [replace] = getCountryNameMatches(unmatched)
            % First thing we wnat to do is replace known abbreviations used
            % in the database
            replaceVals = [{'Is\.'},{'Isds'};...
                {'Islands'},{'Isds'};...
                {'I\.'},{'Isds'};...
                {'Democratic'},{'Dem\.'};...
                {'Republic'},{'Rep\.'};...
                {'British'},{'Br\.'};...
                {'Territory'},{'Terr\.'};...
                {'&'},{'and'};...
                {'St.'},{'Saint'}];
            firstStep = unmatched;
            for i=1:length(unmatched)
                for j=1:size(replaceVals,1)
                    firstStep{i} = regexprep(firstStep{i},replaceVals{j,1},replaceVals{j,2});
                end %for 
            end %for
            %Now run getCodes for these fields
            newMatches = Country.getCodes(firstStep,Country.Name,Country.Code);
            
            %And for the unmatched ones do the countryfuzzymatch table
            % Check our COuntryFuzzyMatch table
            db = DataBasePG;
            db.db = 'Router';
            for i=1:size(unmatched,1)
                unmatched(i,1) = {strrep(char(unmatched(i,1)),'''','''''')};
            end %for
            replace = cell(size(unmatched));
            for i=1:size(replace,1)
                if newMatches(i)==-1 
                    tmp = db.executeQuery(sprintf(['select "dbName" from "CountryFuzzyMatch"'...
                        ' where UPPER("SourceName") = UPPER(''%s'') limit 1'],char(unmatched(i,1))));
                    if ~strcmp(tmp,'No Data')
                        replace(i,1) = tmp;
                    end
                else
                    %we matched by replacement above so use that match
                    replace(i,1) = Country.getCodes(newMatches(i),Country.Code,Country.Name);
                end %if
            end %for
            
        end %getCountryNameMatches
        
        
        
    end %private static methods
end

