%% ============================================================
%  (1) alpha_R vs alpha_F: the parameters conceptually equivalent to
%      the earlier tau_regret vs tau_relief comparison (these control
%      how fast each pathway's value estimate updates/forgets, not
%      just the amplitude of the counterfactual nudge).
%  (2) Cross-parameter correlation check: is the alpha_regret/relief
%      asymmetry actually a trade-off with alpha_R/alpha_F?
%
% ============================================================

load('QL_model_results.mat', 'results_params');
sigmoid = @(x) 1./(1+exp(-x));

n_subjects = size(results_params, 1);
alpha_R_all      = nan(n_subjects,1);
alpha_F_all      = nan(n_subjects,1);
alpha_regret_all = nan(n_subjects,1);
alpha_relief_all = nan(n_subjects,1);

for s = 1:n_subjects
    th = results_params{s,3};  % M3 fit
    if any(isnan(th)), continue; end
    alpha_R_all(s)      = sigmoid(th(1));
    alpha_F_all(s)       = sigmoid(th(2));
    alpha_regret_all(s) = sigmoid(th(3));
    alpha_relief_all(s) = sigmoid(th(4));
end

valid = ~isnan(alpha_R_all) & ~isnan(alpha_F_all);

%% ---- (1) alpha_R vs alpha_F: the real tau-equivalent comparison ----
fprintf('======== (1) alpha_R (chosen-arm updating) vs alpha_F (fictive updating) ========\n');
fprintf('Mean alpha_R = %.3f, Mean alpha_F = %.3f\n', ...
    mean(alpha_R_all(valid)), mean(alpha_F_all(valid)));
[~, p_RF, ~, stats_RF] = ttest(alpha_R_all(valid), alpha_F_all(valid));
fprintf('Paired t-test: t(%d) = %.3f, p = %.5f\n', stats_RF.df, stats_RF.tstat, p_RF);
fprintf(['(higher alpha_R than alpha_F would mean the chosen-arm/regret pathway forgets FASTER - ' ...
    'this is the comparison that should be checked against the earlier tau_regret < tau_relief finding)\n']);

%% ---- (2) Cross-parameter correlations (trade-off diagnostic) ----
fprintf('\n======== (2) Cross-parameter correlations across subjects ========\n');
pairs_to_check = { ...
    'alpha_R','alpha_regret', alpha_R_all, alpha_regret_all; ...
    'alpha_F','alpha_relief', alpha_F_all, alpha_relief_all; ...
    'alpha_R','alpha_F',      alpha_R_all, alpha_F_all; ...
    'alpha_regret','alpha_relief', alpha_regret_all, alpha_relief_all};

for i = 1:size(pairs_to_check,1)
    name1 = pairs_to_check{i,1}; name2 = pairs_to_check{i,2};
    v1 = pairs_to_check{i,3}; v2 = pairs_to_check{i,4};
    m = ~isnan(v1) & ~isnan(v2);
    [r, p] = corr(v1(m), v2(m));
    fprintf('corr(%s, %s) = %.3f, p = %.4f\n', name1, name2, r, p);
end
fprintf(['\nA strong NEGATIVE correlation between alpha_F and alpha_relief (or alpha_R and ' ...
    'alpha_regret) would indicate the optimizer is trading off amplitude against updating ' ...
    'rate for the SAME pathway - a sign these two parameters are not well separately ' ...
    'identifiable and should be interpreted jointly (e.g. as a single "effective decay" per ' ...
    'pathway) rather than as independent claims.\n']);

%% ---- scatter plots ----
figure('Color','w','Position',[50 50 1000 400]);
subplot(1,2,1);
scatter(alpha_R_all(valid), alpha_regret_all(valid), 30, 'filled');
xlabel('\alpha_R'); ylabel('\alpha_{regret}');
title('Chosen-arm pathway: base learning vs regret nudge');
grid on; axis square;

subplot(1,2,2);
scatter(alpha_F_all(valid), alpha_relief_all(valid), 30, 'filled');
xlabel('\alpha_F'); ylabel('\alpha_{relief}');
title('Notchosen-arm pathway: fictive learning vs relief nudge');
grid on; axis square;
