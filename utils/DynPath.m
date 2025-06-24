% classdef DynPath
%     %DYNPATH Summary of this class goes here
%     %   Detailed explanation goes here
%     
%     properties
%         Property1
%     end
%     
%     methods
%         function obj = DynPath(inputArg1,inputArg2)
%             %DYNPATH Construct an instance of this class
%             %   Detailed explanation goes here
%             obj.Property1 = inputArg1 + inputArg2;
%         end
%         
%         function outputArg = method1(obj,inputArg)
%             %METHOD1 Summary of this method goes here
%             %   Detailed explanation goes here
%             outputArg = obj.Property1 + inputArg;
%         end
%     end
% end


classdef DynPath < Path
    properties (Access = public)
        dynamicVariables % Map to store dynamic variables and their values
    end
    
    methods
        % Constructor
        function obj = DynPath(pathPattern, variable, value)
            % Call the constructor of the base class
            obj@Path(pathPattern);
            
            % Initialize the dynamic variables map
            obj.dynamicVariables = containers.Map;
            obj = obj.set(variable, value); 
        end
        
        % Method to set dynamic variables
        function obj = set(obj, variable, value)
            % Store the dynamic variable and its xvalue in the map
            obj.dynamicVariables(variable) = value;
        end
        
        % Method to set dynamic variables
        function value = get(obj, variable)
            % Store the dynamic variable and its xvalue in the map
            value = obj.dynamicVariables(variable);
        end

        function str = print(obj)
            fprintf(string(obj))
        end

        % Overridden method to convert object to string
        function str = char(obj)
            % Get the original path from the base class
            str = char@Path(obj);
            
            % Replace dynamic variables with their values
            dynamicKeys = keys(obj.dynamicVariables);
            for i = 1:length(dynamicKeys)
                variable = dynamicKeys{i};
                value = obj.dynamicVariables(variable);
                
                % Replace dynamic variable with its value in the string
                str = strrep(str, ['{' variable '}'], value);
            end
        end

        function str = string(obj)
            % Get the original path from the base class
            str = string@Path(obj);
        end

        function str = compile(obj)
        % Get the original path from the base class
        str = string(obj);  
        
        % Replace dynamic variables with their values
        dynamicKeys = keys(obj.dynamicVariables);
        for i = 1:length(dynamicKeys)
            variable = dynamicKeys{i};
            value = obj.dynamicVariables(variable);
            
            % Replace dynamic variable with its value in the string
            str = strrep(str, ['{' variable '}'], value);
        end
    end

    end
end

