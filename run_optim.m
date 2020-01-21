function run_optim()

close('all')
addpath(genpath('src'))

%% optim
param = get_data('brute_force');
data_brute = get_optim('brute_force', param);

param = get_data('pattern_search');
data_ps = get_optim('pattern_search', param);

% param = get_data('genetic_single_obj');
% data_ga = get_optim('genetic_single_obj', param);
% 
% param = get_data('genetic_multi_obj');
% data_gamultiobj = get_optim('genetic_multi_obj', param);

%% plot
figure()
plot(data_brute.sol.y_1, data_brute.sol.y_2, 'xb')
hold('on')
plot(data_ps.sol.y_1, data_ps.sol.y_2, 'og')



% plot(data_ga.sol.y_1, data_ga.sol.y_2, 'og')
% plot(data_gamultiobj.sol.y_1, data_gamultiobj.sol.y_2, '+r')
% grid('on')
% legend('brute force', 'genetic single obj', 'genetic multi obj')
% xlabel('y_{1}')
% ylabel('y_{2}')

end
