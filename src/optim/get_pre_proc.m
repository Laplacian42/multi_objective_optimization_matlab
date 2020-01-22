function [optim, n_var, n_sweep] = get_pre_proc(var_param)
%GET_PRE_PROC Parse and scale the input variables, generates the initial points.
%   [optim, n_var, n_sweep] = GET_PRE_PROC(var_param)
%   var_param - struct with the variable description (struct)
%      data.n_max - maximum number of initial points for avoid out of memory crashed (integer)
%      data.var - cell of struct with the different variable description (cell of struct)
%          data.var{i}.type - type of the variable (string containing 'lin_float')
%          data.var{i}.name - name of the variable (string)
%          data.var{i}.v - value of the single constant variable (float)
%          data.var{i} - description of a float variable with linear scale (type is 'lin_float')
%              data.var{i}.lb - lower boundary for the variable (float)
%              data.var{i}.ub - upper boundary for the variable (float)
%              data.var{i}.v_1 - lower boundary for the initial points (float)
%              data.var{i}.v_2 - upper boundary for the initial points (float)
%              data.var{i}.n - number of initial points (integer)
%          data.var{i} - description of a float variable with logarithmic scale (type is 'log_float')
%              data.var{i}.lb - lower boundary for the variable (float)
%              data.var{i}.ub - upper boundary for the variable (float)
%              data.var{i}.v_1 - lower boundary for the initial points (float)
%              data.var{i}.v_2 - upper boundary for the initial points (float)
%              data.var{i}.n - number of initial points (integer)
%          data.var{i} - description of an integer variable (type is 'integer')
%              data.var{i}.set - integer with the set of possible values (array of integer)
%              data.var{i}.vec - integer with the initial combinations (array of integer)
%          data.var{i} - description of a constant (non-optimized) variable (type is 'scalar')
%   optim - struct with the parsed variables (struct)
%      optim.lb - array containing the lower bounds of the variables (array of float)
%      optim.ub - array containing the upper bounds of the variables (array of float)
%      optim.int_con - array containing the index of the integer variables (array of integer)
%      optim.input - struct containing the constant (non-optimized) variables (struct of scalars)
%      optim.x0 - matrix containing the scaled initial points (matrix of float)
%      optim.var_scale - cell containing the function to unscale the variables (cell of struct)
%         optim.var_scale{i}.name - name of the variable (string)
%         optim.var_scale{i}.fct_unscale - function for unscaling the variables (function handle)
%   n_var - number of input variables used for the optimization (integer)
%   n_sweep - number of initial points used by the algorithm (integer)
%
%   This function performs the following tasks on the variables:
%      - Find the lower and upper bounds
%      - Find the integer variables
%      - Find the constant variables
%      - Spanning the initial points
%      - Scaling the integer:
%         - Doing nothing for 'lin_float' variables
%         - Optimizing with the log of the given variable for 'log_float' variables
%         - Mapping integer variables from [x1, x1, ..., xn] to [1, 2, ..., n]
%
%   See also GET_OPTIM, GET_SOLUTION.

%   Thomas Guillod.
%   2020 - BSD License.


% extract the provided data
var = var_param.var;
n_max = var_param.n_max;
fct_select = var_param.fct_select;

% init the output
var_scale = {};
lb = [];
int_con = [];
ub = [];
x0_cell = {};
input = struct();

% parse the different variable
for i=1:length(var)
    var_tmp = var{i};
    
    switch var_tmp.type
        case 'scalar'
            % scalar variable should not be array, assign them to the input struct
            assert(length(var_tmp.v)==1, 'invalid data')
            input.(var_tmp.name) = var_tmp.v;
        case 'integer'
            % check that the initial points respect the set
            assert(length(var_tmp.set)>1, 'invalid data')
            assert(length(var_tmp.v)==1, 'invalid data')
            assert(all(ismember(var_tmp.vec, var_tmp.set)), 'invalid data')
            assert(all(ismember(var_tmp.v, var_tmp.set)), 'invalid data')
            
            [fct_scale, fct_unscale] = get_scale('integer');

            % mapping integer variables from [x1, x1, ..., xn] to [1, 2, ..., n]
            var_scale{end+1} = struct('name', var_tmp.name, 'fct_unscale',  @(x) fct_unscale(var_tmp.set, x));
            x0_cell{end+1} = fct_scale(var_tmp.set, var_tmp.vec);
            
            % flag the integer variable
            int_con(end+1) = length(var_scale);
                        
            % set the bounds in the transformed coordinates
            lb(end+1) = min(fct_scale(var_tmp.set, var_tmp.set));
            ub(end+1) = max(fct_scale(var_tmp.set, var_tmp.set));
        case 'float'
            % check that the initial points respect the bounds
            assert(length(var_tmp.v)==1, 'invalid data')
            assert(var_tmp.ub>=var_tmp.lb, 'invalid data')
            assert(all(var_tmp.v>=var_tmp.lb)&&all(var_tmp.v<=var_tmp.ub), 'invalid data')
            assert(all(var_tmp.vec>=var_tmp.lb)&&all(var_tmp.vec<=var_tmp.ub), 'invalid data')
            
            [fct_scale, fct_unscale] = get_scale(var_tmp.scale);
            
            % no variable transformation, generate the initial points
            var_scale{end+1} = struct('name', var_tmp.name, 'fct_unscale', fct_unscale);
            x0_cell{end+1} = fct_scale(var_tmp.vec);
            
            % set the bounds
            lb(end+1) = fct_scale(var_tmp.lb);
            ub(end+1) = fct_scale(var_tmp.ub);
        otherwise
            error('invalid data')
    end
end

% compute the input
fct_input = @(x) get_input_from_x(x, input, var_scale);

% span all the combinations between the initial points
x0_mat = get_x0(x0_cell, fct_input, fct_select);

% get the size of the variable
[n_var, n_sweep] = get_size(x0_cell, n_max);

% assign the data
optim.fct_input = fct_input;
optim.lb = lb;
optim.ub = ub;
optim.int_con = int_con;
optim.x0_mat = x0_mat;

end

function [n_var, n_sweep] = get_size(x0_cell, n_max)
%GET_SIZE Get and check the number of initial points.
%   [n_var, n_sweep] = GET_SIZE(x0_cell, n_max)
%   x0_cell - initial points of the different variables (cell of float arrays)
%   n_max - maximum number of initial points for avoid out of memory crashed (integer)
%   n_var - number of input variables used for the optimization (integer)
%   n_sweep - number of initial points used by the algorithm (integer)

% all the combinations between the initial points
n_sweep = prod(cellfun(@length, x0_cell));
n_sweep = max(1, n_sweep);
assert(n_sweep<=n_max, 'invalid data');
assert(n_sweep>0, 'invalid data');

% number of optimization variables
n_var = length(x0_cell);
assert(n_var>0, 'invalid data');

end

function x0_mat = get_x0(x0_cell, fct_input, fct_select)
%GET_X0 Span all the combinations between the initial points.
%   x0 = GET_X0(x0_cell)
%   x0_cell - initial points of the different variables (cell of float arrays)
%   x0_mat - matrix containing the scaled initial points (matrix of float)

% get all the combinations
x0_tmp = cell(1,length(x0_cell));
[x0_tmp{:}] = ndgrid(x0_cell{:});
for i=1:length(x0_tmp)
    x0_mat(:,i) = x0_tmp{i}(:);
end

% filter the combinations
[input, n_sweep] = fct_input(x0_mat);
idx_select = fct_select(input, n_sweep);
x0_mat = x0_mat(idx_select, :);

end

function [input, n_sweep] = get_input_from_x(x, input, var_scale)
%GET_SWEEP_FROM_X Parse and unscale the optimized variables.
%   [sweep, n_sweep] = GET_SWEEP_FROM_X(x, var_scale)
%   x - matrix containing the scaled points to be computed (matrix of float)
%   var_scale - cell containing the function to unscale the variables (cell of struct)
%   sweep - struct containing the scaled variables to be optimized (struct of arrays)
%   n_sweep - number of solutions to be computed (integer)
%
%   See also GET_SOLVE_OBJ, GET_SOLVE_SOL, GET_SOLUTION.

% get the number of points
n_sweep = size(x, 1);

% unscaled the variable
for i=1:length(var_scale)
    % extract the data
    name = var_scale{i}.name;
    fct_unscale = var_scale{i}.fct_unscale;
    
    % select the variable and unscale
    x_tmp = x(:,i).';
    sweep.(name) = fct_unscale(x_tmp);
end

% extend the constant variable to the chunk size
input = get_struct_size(input, n_sweep);

% merge the optimized and constant variables
field = [fieldnames(input) ; fieldnames(sweep)];
value = [struct2cell(input) ; struct2cell(sweep)];
input = cell2struct(value, field);

end

function [fct_scale, fct_unscale] = get_scale(scale)

switch scale
    case 'integer'
        fct_scale = @(set, vec) find(ismember(set, vec));
        fct_unscale = @(set, vec) set(vec);
    case 'lin'
        fct_scale = @(x) x;
        fct_unscale = @(x) x;
    case 'log'
        fct_scale = @(x) log10(x);
        fct_unscale = @(x) 10.^x;
    case 'exp'
        fct_scale = @(x) 10.^x;
        fct_unscale = @(x) log10(x);
    otherwise
        error('invalid data')
end

end