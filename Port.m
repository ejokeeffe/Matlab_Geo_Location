%> @file Port.m
%
%> @brief Class to read in ports from Postgres DB
%
%> @section matlabComments Details
%> @authors Eoin O'Keeffe (eoin.okeeffe.09@ucl.ac.uk)
%> @date initiated: 24/05/2011
%> <br /> Version 2.0: 01/08/2011 
%> <br /><i> Version 2.1</i> 19/12/2012
%>
%> @version 
%> 1.0: Basic static function set up to read in ports
%> <br /> Version 1.1: Edited getSinglePortPerCountry so you can specify
%> the country list
%> <br /> Version 2.0: getPorts changed to getAllPorts, so getPorts now
%> gets a list of ports based on passed references
%> <br /><i>Version 2.1</i>: Function added that gets the id of the port
%> based on a passed name of port. This is only for ais derived ports
%>
%> @section intro Method
%> 
%> @subsection Data
%> @attention
%> @todo Get commodities associated with ports and build the correct ports
%> for particular commodities. Maybe combined singleport per country function with getPorts but
%> getPorts has an additional argument
classdef Port
  properties
    
  end
        properties(Constant)
    %> Port ID in database
    PortID = 1
    %> Port Name
    Name =2
    %> CountryCode
    CCode=4
    %> Longitude
    X = 5;
    %> Latitude
    Y = 6;
        end %Constant properties
    methods (Access=public, Static=true)
    % ======================================================================
    %> @brief Get the full list of ports (about 20,000 in all)
    %>
    %> This method is public and static
    %> @retval x list of ports in dataset [.ID .CountryCode .Long .Lat] 
    % =====================================================================
    function [x] = getAllPorts()
        persistent ports;
        if isempty(ports)
            db=DataBasePG();
            db.db = 'Router';
            ports = db.getAll('Ports');
            %Reset ports to the following dataset
            tmp = dataset;
            tmp.ID = cell2mat(ports(:,1));
            tmp.CCode = cell2mat(ports(:,4));
            tmp.lon = cell2mat(ports(:,5));
            tmp.lat = cell2mat(ports(:,6));
            ports = tmp;
        end %if
        x = ports;
    end %function getPorts
    % ======================================================================
    %> @brief Get the full list world port source ports
    %>
    %> This method is public and static
    %> @retval x list of ports in dataset [.ID .CountryCode .Long .Lat] 
    % =====================================================================
    function [ports] = getAllWPSPorts()
       % persistent ports;
        %if isempty(ports)
            db=DataBasePG();
            db.db = 'Router';
            ports = db.executeQuery(['select * from "WorldPortSource"'...
                'where "Port Type" in (''Seaport'',''Deepwater Seaport'',''Port Terminal'')']);
            %Reset ports to the following dataset
            tmp = dataset;
            tmp.ID = cell2mat(ports(:,1));
            tmp.name = ports(:,2);
            tmp.CCode = cell2mat(ports(:,9));
            tmp.lon = cell2mat(ports(:,4));
            tmp.lat = cell2mat(ports(:,5));
            tmp.uncode = ports(:,6);
            ports = tmp;
        %end %if
        %x = ports;
    end %function getPorts
    % ======================================================================
    %> @brief Get the full list world shipping register ports
    %>
    %> This method is public and static
    %> @retval x list of ports in dataset [.ID .CountryCode .Long .Lat .name .maxDraught] 
    % =====================================================================
    function [ports] = getAllWSRPorts()
       % persistent ports;
        %if isempty(ports)
            db=DataBasePG();
            db.db = 'Router';
            ports = db.executeQuery(['select "ID", "Longitude","Latitude",'...
                '(select "Cty Code" from "ComtradeCountryCodes" where '...
                '"ISO2-digit Alpha" = substring("UNCTAD" from 1 for 2) limit 1),"UNCTAD"'...
                ',"Name","Max Draft" from "WorldShippingRegister"'...
                'where "Status" = ''Port Open''']);
            %Reset ports to the following dataset
            tmp = dataset;
            tmp.ID = cell2mat(ports(:,1));
            tmp.CCode = cell2mat(ports(:,4));
            tmp.lon = cell2mat(ports(:,2));
            tmp.lat = cell2mat(ports(:,3));
            tmp.uncode = ports(:,5);
            tmp.name = ports(:,6);
            tmp.maxDraught = zeros(size(tmp.name));
            indxs = cellfun(@(x) ~strcmp(x,''),ports(:,7));
            tmp.maxDraught(indxs) = cell2mat(cellfun(@(x) str2num(x),ports(:,7),'un',0));
            ports = tmp;
        %end %if
        %x = ports;
    end %function getPorts
    % ======================================================================
    %> @brief Get the full list of locodes
    %>
    %> This method is public and static
    %> @retval x list of ports in dataset [.ID .CountryCode .Long .Lat .name .maxDraught] 
    % =====================================================================
    function [ports] = getAllLocodePorts()
            db=DataBasePG();
            db.db = 'Router';
            ports = db.executeQuery(['select "ID", "Name","CountryCode",'...
                '"Long","Lat",(select "ISO2-digit Alpha" from "ComtradeCountryCodes" where '...
                '"Cty Code" = "CountryCode") "PortAbbr" from "Ports"']);
            %Reset ports to the following dataset
            tmp = dataset;
            tmp.ID = cell2mat(ports(:,1));
            tmp.CCode = cell2mat(ports(:,3));
            tmp.lon = cell2mat(ports(:,4));
            tmp.lat = cell2mat(ports(:,5));
            tmp.uncode = ports(:,6);
            tmp.name = ports(:,2);
            ports = tmp;
    end %function getPorts
    % ======================================================================
    %> @brief Get the full list of ports  but as a cell array. Data is not
    %> maintained within function as it would be storage heavy
    %>
    %> This method is public and static
    %> @retval x list of ports as cell array in same format as database 
    %> [ID Name Desc CountryCode Long Lat PortAbbr]
    % =====================================================================
    function [x] = getPortsVerbose()
            db=DataBasePG();
            db.db = 'Router';
            x = db.getAll('Ports');
    end %function getPorts
   % ======================================================================
    %> @brief Get the list of ports (1 per country) 
    %>
    %> This method is public and static
    %> @param ctries (optional) allows user to set the countries to get a
    %> port for
    %> @retval x list of ports in dataset [.ID .CountryCode .Long .Lat] 
    % =====================================================================
    function [x] = getSinglePortPerCountry(ctries)
        if nargin==0
            ctries = [];
        end 
       % persistent singlePorts;
        %if isempty(singlePorts)
            %Get all the ports first
            ports = Port.getAllWPSPorts();
            %Remove ports that have an X of -1 or a Y of -1 and ccountry
            %codes of -1
            ports = ports(ismember([ports.lon~=-1 ports.lat~=-1 ports.CCode~=-1],...
                ones(size(ports.lon,1),3),'rows'),:);
            %Now select the first instance of each country mention
            [~,tmpIndxs] = unique(ports.CCode);
            singlePorts = ports(tmpIndxs,:);

            
      %  end %if
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Edited EO'K 29/07/2011
            % if ctries is passed in, then only return ports for those
            % countries, in the same order as the countries
        if ~isempty(ctries)
            %x = singlePorts(Useful.matchMatrices(,ctries),:);
            [ctriesIndxs,portIndxs] = ismember(ctries,singlePorts.CCode);
            x=zeros(length(ctries),1);
            x(ctriesIndxs,:) = singlePorts.CCode(portIndxs(portIndxs~=0,:),:);
        else
            x = singlePorts;
    end
    end %function getSinglePortPerCountry
    % ======================================================================
    %> @brief Get a port based on passed ID/Name/etc
    %>
    %> This method is public and static
     %> @param ref the vector containing the reference codes
    %> @param enum the type of identifier (see the constant properties)
    %> @param verbose if 0 or empty only return matrix otherwise pass back
    %> cell array incl name
    %> @retval ports ports vector corresponding to ref [ID CCode Long Lat.
    %> This could return multiple results for a particular Name.
    
    % =====================================================================
    function [ports] = getPorts(ref,enum,verbose)
        if nargin==2
            verbose =0;
        end 
        db = DataBasePG;
        db.db = 'Router';
        ports=[];
        for i=1:size(ref)
         if enum == Port.Name
             tmpPort = db.executeQuery(['Select "ID","Name","CountryCode", "Long",'...
                 '"Lat" from "Ports" where upper("Name") = ''' upper(char(ref(i,1))) '''']);
             if ~isempty(tmpPort)
                 if verbose ==0
                    ports = [ports;cell2mat([tmpPort(:,1) zeros(size(tmpPort,1),2) tmpPort(:,3:5)])];
                 else
                     
                    ports = [ports;[tmpPort(:,1:2) num2cell(zeros(size(tmpPort,1),1)) tmpPort(:,3:5)]];
                 end %if
             end %
         elseif enum == Port.PortID
             tmpPort = db.executeQuery(['Select "ID","Name","CountryCode", "Long",'...
                 '"Lat" from "Ports" where "ID" = ' char(ref(i,1))]);
             if ~isempty(tmpPort)
                 if verbose ==0
                    ports = [ports;cell2mat([tmpPort(:,1) zeros(size(tmpPort,1),2) tmpPort(:,3:5)])];
                 else
                    
                    ports = [ports;[tmpPort(:,1:2) num2cell(zeros(size(tmpPort,1),1)) tmpPort(:,3:5)]];
                 end %if
             end %if
         end %if
        end %for i
    end %function getPorts
    
    %-----------------------------------------------------------------------
    %> @brief returns the id from the database based on a passed port name
    %> - Only for the ais derived ports list. The fuzzy match db is also
    %> consulted
    %>
    %> @param name
    %> @param portsTable the name of the table from which the port name
    %> should derive
    %> @param fuzzymatchTable the name of the fuzzy match table
    %> @param db the name of the database [optional] - defaults to
    %> ExactEarth
    %> @retval id id of the port or -1 for no match
    %> @retval name the correct name of the port
    function getIdFromAisPorts(name,portsTable,fuzzymatchTable,dbName)
        if nargin==3
            dbName='ExactEarth';
        end %if
        
        db = DataBasePG;
        db.db = dbName;
        
        %first see if there's an exact match
        data = db.executeQuery(sprintf('select id,name from "%s" where name = ''''',...
            portsTable,strtrim(strrep(name,'''',''''''))));
        if isa(data{1},'char')
            %no match
            %lets try the fuzzymatchtable
            %data = 
        else
            id = data{1,1};
            name = data{1,2};
        end %if
    end %getIdFromAisPorts
    end %methods static public
end

