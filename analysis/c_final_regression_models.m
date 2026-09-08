% Guidance:

% First, I z-scored the variables within each subject to ensure that the
% correlations were not driven by between subject differences. 

% 0 (lines: ): Does regret improve fit over raw reward values alone?
% 1 (lines: ): Does random reward affect credit assinment? 
% 2 (lines: ): Null model comparison among all models made by far
% 3 (lines: ): individual analysis for random rewards
% 4 (lines: ): does random-reward misattribution moderate the effect of Regret_chosen on choice?
% 5 (lines: ): Reward & Regret decay comparison
% 6 (lines: ): Regret & Relief comparison (effect & decay )

basePath = 'D:\my task\subjects\all\run_based\final_touch'; 

n_history    = 6;
moveDuration = 4;
half_trial   = moveDuration / 2;
arms         = {'circle','square','triangle'}; 
alpha   = 0.4;  % decay rate for comulative regret

files = dir(fullfile(basePath,'*_results.mat'));
names = cell(size(files));
for i = 1:length(files)
    names{i} = strrep(files(i).name, '_results.mat', '');
end
names = sort(names);
n_subjects = length(names)/2;
subject_files = cell(n_subjects,1);
for i = 1:n_subjects
    subject_files{i} = {names{2*i-1}, names{2*i}};
end

% If you have already created the table, just load it instead of creating it again.
T = build_T_general(alpha, basePath, subject_files, n_subjects, arms, n_history, half_trial);

%% === save or load the table ===
save('T_final.mat','T','-v7.3'); 
load('T_final.mat','T');

%% == z-score trial within each (subject, session) pair(not just subject) ==
% because trial numbers reset at the start of each session
T.Trial_z = nan(height(T),1);
subj_list = unique(T.Subject);
for i = 1:length(subj_list)
    for sess = 1:2
        m = (T.Subject == subj_list(i)) & (T.Session == sess);
        if any(m)
            T.Trial_z(m) = (T.Trial(m) - mean(T.Trial(m))) / std(T.Trial(m));
        end
    end
end

opts = statset('MaxIter', 500, 'TolFun', 1e-8, 'TolX', 1e-8);  % default MaxIter (100) is often not enough here


%% ---- (1) list every continuous predictor to standardize ----
lags = {'L1','L2','L3','L4','L5','L6'};
predictor_base_names = {'Reward_chosen_','Reward_notchosen_','Regret_chosen_','Relief_notchosen_'};

predictor_cols = {};
for b = 1:length(predictor_base_names)
    for L = 1:length(lags)
        predictor_cols{end+1} = [predictor_base_names{b} lags{L}]; 
    end
end

extra_cols = {'CumRegret_diff','CumRegret_mean_all'};
for e = 1:length(extra_cols)
    if ismember(extra_cols{e}, T.Properties.VariableNames)
        predictor_cols{end+1} = extra_cols{e};
    end
end

predictor_cols = predictor_cols(ismember(predictor_cols, T.Properties.VariableNames));
fprintf('Will z-score %d predictor columns, WITHIN each subject:\n', length(predictor_cols));
disp(predictor_cols');

%% ---- (2) do z-scoring ----
% For each predictor column, and for each subject separately, subtract
% that subject's own mean and divide by that subject's own SD. Results
% go into new columns with a "_z" suffix. And the original raw columns are
% left untouched, so we can compare both.
subj_list = unique(T.Subject);

for c = 1:length(predictor_cols)
    col   = predictor_cols{c};
    z_col = [col '_z'];
    T.(z_col) = nan(height(T), 1);

    for i = 1:length(subj_list)
        m = T.Subject == subj_list(i);
        vals = T.(col)(m);
        mu = mean(vals);
        sd = std(vals);
        if sd == 0 || isnan(sd)
            % this subject had zero variance on this predictor (rare)
            % so just set to 0 rather than dividing by zero
            T.(z_col)(m) = 0;
        else
            T.(z_col)(m) = (vals - mu) / sd;
        end
    end
end


%% ===  (3) Compare correlation matrices: raw vs z-scored (within subject)==

raw_cols = predictor_cols;
z_cols   = strcat(predictor_cols, '_z');

R_raw = corr(T{:, raw_cols}, 'rows','complete');
R_z   = corr(T{:, z_cols},   'rows','complete');

mask = ~eye(size(R_raw));  % Logical mask excluding diagonal (self-correlations)
fprintf('\n=== Overall comparison ===\n');
fprintf('Mean |correlation| RAW       = %.4f\n', mean(abs(R_raw(mask))));
fprintf('Mean |correlation| Z-SCORED  = %.4f\n', mean(abs(R_z(mask))));

fprintf('\n=== Pairs where |correlation| dropped by more than 0.05 after z-scoring ===\n');
found_any = false;
for i = 1:length(raw_cols)
    for j = i+1:length(raw_cols)
        drop = abs(R_raw(i,j)) - abs(R_z(i,j));
        if drop > 0.05
            found_any = true;
            fprintf('%-25s x %-25s : raw r=%.3f -> z r=%.3f (drop=%.3f)\n', ...
                raw_cols{i}, raw_cols{j}, R_raw(i,j), R_z(i,j), drop);
        end
    end
end
if ~found_any
    fprintf('(no pair dropped by more than 0.05)\n');
end

%% ---- side-by-side heatmaps ----
figure('Color','w','Position',[50 50 1300 600]);
subplot(1,2,1);
imagesc(R_raw); caxis([-1 1]); colorbar;
title('Correlation matrix - RAW (pooled across subjects)');
set(gca,'XTick',1:length(raw_cols),'XTickLabel',strrep(raw_cols,'_','\_'), ...
    'XTickLabelRotation',90,'FontSize',6);
set(gca,'YTick',1:length(raw_cols),'YTickLabel',strrep(raw_cols,'_','\_'),'FontSize',6);

subplot(1,2,2);
imagesc(R_z); caxis([-1 1]); colorbar;
title('Correlation matrix - Z-SCORED (within subject)');
set(gca,'XTick',1:length(z_cols),'XTickLabel',strrep(raw_cols,'_','\_'), ...
    'XTickLabelRotation',90,'FontSize',6);
set(gca,'YTick',1:length(z_cols),'YTickLabel',strrep(raw_cols,'_','\_'),'FontSize',6);

%% raw correlation matrix
figure('Color','w','Position',[50 50 700 600]);
imagesc(R_raw);
caxis([-1 1]);
colorbar;
title('Correlation matrix - RAW (pooled across subjects)');

set(gca,'XTick',1:length(raw_cols), ...
    'XTickLabel',strrep(raw_cols,'_','\_'), ...
    'XTickLabelRotation',90, ...
    'FontSize',6);

set(gca,'YTick',1:length(raw_cols), ...
    'YTickLabel',strrep(raw_cols,'_','\_'), ...
    'FontSize',6);

%% Z-scored correlation matrix
figure('Color','w','Position',[800 50 700 600]);
imagesc(R_z);
caxis([-1 1]);
colorbar;
title('Correlation matrix - Z-SCORED (within subject)');

set(gca,'XTick',1:length(z_cols), ...
    'XTickLabel',strrep(raw_cols,'_','\_'), ...
    'XTickLabelRotation',90, ...
    'FontSize',6);

set(gca,'YTick',1:length(z_cols), ...
    'YTickLabel',strrep(raw_cols,'_','\_'), ...
    'FontSize',6);


%% ===  (4) Build z-scored term strings for use in our regression models
make_terms_z = @(prefix) strjoin(cellfun(@(L) [prefix L '_z'], lags, ...
                'UniformOutput',false), ' + ');

reward_cho_terms_z  = make_terms_z('Reward_chosen_');
reward_nc_terms_z   = make_terms_z('Reward_notchosen_');
regret_cho_terms_z  = make_terms_z('Regret_chosen_');
relief_nc_terms_z   = make_terms_z('Relief_notchosen_');

fprintf('\nZ-scored term strings ready to use in formulas:\n');
fprintf('reward_cho_terms_z  = %s\n', reward_cho_terms_z);
fprintf('regret_cho_terms_z  = %s\n', regret_cho_terms_z);

%% ---- example: refita model with z-scored predictors ----
f_reward_regret_z = ['Choice_top ~ ' reward_cho_terms_z ' + ' reward_nc_terms_z ' + ' ...
    regret_cho_terms_z ' + ' relief_nc_terms_z ' + (1|Subject)'];


 mdl_z = fitglme(T, f_reward_regret_z, 'Distribution','Binomial','Link','logit', ...
     'FitMethod','Laplace','OptimizerOptions',opts);
 disp(mdl_z.Coefficients);
%%  Does the global correlation hide a much stronger collinearity within the subset where Regret>0?
% answer: no

for k = 1:3
    reg_col = ['Regret_chosen_L' num2str(k)];
    rc_col  = ['Reward_chosen_L' num2str(k)];
    rnc_col = ['Reward_notchosen_L' num2str(k)];

    is_positive = T.(reg_col) > 0;

    fprintf('=== Lag %d ===\n', k);
    fprintf('Fraction of trials with Regret>0: %.2f%%\n', 100*mean(is_positive));

    r_global = corr(T.(reg_col), T.(rnc_col) - T.(rc_col));
    r_local  = corr(T.(reg_col)(is_positive), ...
                     T.(rnc_col)(is_positive) - T.(rc_col)(is_positive));

    fprintf('corr(Regret, Reward_notchosen - Reward_chosen) - ALL trials:      r = %.3f\n', r_global);
    fprintf('corr(Regret, Reward_notchosen - Reward_chosen) - Regret>0 only:   r = %.3f\n', r_local);
    fprintf('\n');
end

fprintf(['The weaker all trial correlation indicates that rectification (max(0,.)) ' ...
    'dilutes a strong local dependency, masking collinearity in correlation/vif diagnostics.\n']);
%% ============================================================
%  (0) Does regret improve fit over raw reward
%      values alone?
% ============================================================

lags = {'L1','L2','L3','L4','L5','L6'};

%% ---- helper: making variable strings ----
make_terms = @(prefix) strjoin(cellfun(@(L) [prefix L], lags, ...
                'UniformOutput',false), ' + ');

reward_cho_terms  = make_terms('Reward_chosen_');
reward_nc_terms   = make_terms('Reward_notchosen_');
regret_cho_terms  = make_terms('Regret_chosen_');
relief_nc_terms   = make_terms('Relief_notchosen_');
%%
f_reward_only = ['Choice_top ~ ' reward_cho_terms ' + ' reward_nc_terms ' + (1|Subject)'];

fprintf('\n======== (0a) Reward-only model (no regret) ========\n');
mdl_reward_only = fitglme(T, f_reward_only, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace', 'OptimizerOptions', opts);
disp(mdl_reward_only.Coefficients);
fprintf('AIC (reward only) = %.2f, LogLikelihood = %.2f\n', ...
    mdl_reward_only.ModelCriterion.AIC, mdl_reward_only.LogLikelihood);

f_reward_regret = ['Choice_top ~ ' reward_cho_terms ' + ' reward_nc_terms ' + ' ...
          regret_cho_terms ' + (1|Subject)'];

fprintf('\n======== (0b) Reward + regret/relief model ========\n');
mdl_reward_regret = fitglme(T, f_reward_regret, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace', 'OptimizerOptions', opts);
disp(mdl_reward_regret.Coefficients);
fprintf('AIC (reward+regret) = %.2f, LogLikelihood = %.2f\n', ...
    mdl_reward_regret.ModelCriterion.AIC, mdl_reward_regret.LogLikelihood);

fprintf('\n======== (0c) LRT: does regret/relief improve fit over reward-only? ========\n');
ll_r0 = mdl_reward_only.LogLikelihood;
ll_r1 = mdl_reward_regret.LogLikelihood;
df_r  = mdl_reward_regret.NumCoefficients - mdl_reward_only.NumCoefficients;  % should be 6

fprintf('LogLikelihood (reward only)   = %.3f\n', ll_r0);
fprintf('LogLikelihood (reward+regret) = %.3f\n', ll_r1);
fprintf('df difference = %d\n', df_r);

if ll_r1 < ll_r0
    fprintf('Adding regret/relief did NOT increase the log-likelihood - no support for the core claim.\n');
else
    LR_r = 2 * (ll_r1 - ll_r0);
    p_r  = 1 - chi2cdf(LR_r, df_r);
    fprintf('LR statistic = %.4f, df = %d, p = %.10f\n', LR_r, df_r, p_r);
    if p_r < 0.05
        fprintf('Regret significantly improve fit beyond raw reward values.\n');
    else
        fprintf('Regret/relief do not significantly improve fit beyond raw reward values.\n');
    end
end


%% ============================================================
%  1 : Does random reward affect credit assinment? 
% ============================================================

f_base_rnd =['Choice_top ~ ' reward_cho_terms ' + ' reward_nc_terms ' + ' ...
          regret_cho_terms ' + (1|Subject)'];

mdl_base_rnd = fitglme(T, f_base_rnd, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace', 'OptimizerOptions', opts);
aic_base_rnd = mdl_base_rnd.ModelCriterion.AIC;
ll_base_rnd  = mdl_base_rnd.LogLikelihood;

fprintf('\n======== testing 12 variables one by one ========\n');
fprintf('AIC for base model: %.2f\n\n', aic_base_rnd);
fprintf('%-25s %-10s %-10s %-10s %-10s %-10s\n', ...
        'Variable', '?_L1', 'p_L1', 'AIC', '?AIC', 'LRT_p');
fprintf('%s\n', repmat('-',1,75));

rnd_vars = {
    'Rnd_cho_same_t0',  'chosen arm, same pos, choice trial';
    'Rnd_cho_diff_t0',  'chosen arm, diff pos, choice trial';
    'Rnd_cho_any_t0',   'chosen arm, any pos,  choice trial';
    'Rnd_cho_same_t1',  'chosen arm, same pos, feedback trial';
    'Rnd_cho_diff_t1',  'chosen arm, diff pos, feedback trial';
    'Rnd_cho_any_t1',   'chosen arm, any pos,  feedback trial';
    'Rnd_unc_same_t0',  'unchosen arm, same pos, choice trial';
    'Rnd_unc_diff_t0',  'unchosen arm, diff pos, choice trial';
    'Rnd_unc_any_t0',   'unchosen arm, any pos,  choice trial';
    'Rnd_unc_same_t1',  'unchosen arm, same pos, feedback trial';
    'Rnd_unc_diff_t1',  'unchosen arm, diff pos, feedback trial';
    'Rnd_unc_any_t1',   'unchosen arm, any pos,  feedback trial';
};

results_rnd = table();

for r = 1:size(rnd_vars,1)
    vname = rnd_vars{r,1};
    vdesc = rnd_vars{r,2};
    
  
    f_test = [f_base_rnd(1:end-12) ... 
              vname '_L1 + (1|Subject)'];
    
    try
        mdl_test = fitglme(T, f_test, 'Distribution','Binomial','Link','logit', ...
            'FitMethod','Laplace', 'OptimizerOptions', opts);
        
        aic_test = mdl_test.ModelCriterion.AIC;
        ll_test  = mdl_test.LogLikelihood;
        delta_aic = aic_test - aic_base_rnd;
        
       % for L1
        idx = strcmp(mdl_test.CoefficientNames, [vname '_L1']);
        beta_L1 = mdl_test.Coefficients.Estimate(idx);
        p_L1    = mdl_test.Coefficients.pValue(idx);
        
        % LRT
        LR   = 2*(ll_test - ll_base_rnd);
        p_lr = 1 - chi2cdf(LR, 1);
        
       
        if p_L1 < 0.001,     sig = '***';
        elseif p_L1 < 0.01,  sig = '**';
        elseif p_L1 < 0.05,  sig = '*';
        else                 sig = '';
        end
        
        fprintf('%-25s %-10.4f %-10.4f %-10.2f %-10.2f %-10.4f %s\n', ...
                vname, beta_L1, p_L1, aic_test, delta_aic, p_lr, sig);
        
        % saving results
        results_rnd(end+1,:) = table({vname}, {vdesc}, beta_L1, p_L1, aic_test, delta_aic, p_lr, ...
            'VariableNames', {'Variable','Description','Beta_L1','p_L1','AIC','Delta_AIC','LRT_p'});
        
    catch ME
        fprintf('%-25s ERROR: %s\n', vname, ME.message);
    end
end

fprintf('\n======== significant(p < 0.05 & AIC < 0) ========\n');
sig_mask = results_rnd.p_L1 < 0.05 & results_rnd.Delta_AIC < 0;
if any(sig_mask)
    disp(results_rnd(sig_mask, {'Variable','Description','Beta_L1','p_L1','Delta_AIC'}));
else
    fprintf('non of them were significant.\n');
end


%% ============================================================
%  2: Null model comparision
% ============================================================
f_rnd1 = ['Choice_top ~ ' reward_cho_terms ' + ' reward_nc_terms ' + ' ...
          regret_cho_terms ' + Rnd_cho_diff_t0_L1 + (1|Subject)'];

mdl_rnd1 = fitglme(T, f_rnd1, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace', 'OptimizerOptions', opts);
%%
f_rnd2 = ['Choice_top ~ ' reward_cho_terms ' + ' reward_nc_terms ' + ' ...
          regret_cho_terms ' + Rnd_cho_any_t0_L1 + (1|Subject)'];
      

mdl_rnd2 = fitglme(T, f_rnd2, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace', 'OptimizerOptions', opts);
%%
f_rnd3 = ['Choice_top ~ ' reward_cho_terms ' + ' reward_nc_terms ' + ' ...
          regret_cho_terms ' + Rnd_cho_same_t1_L1 + (1|Subject)'];
      
mdl_rnd3 = fitglme(T, f_rnd3, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace', 'OptimizerOptions', opts);
%%
f_rnd4 = ['Choice_top ~ ' reward_cho_terms ' + ' reward_nc_terms ' + ' ...
          regret_cho_terms ' + Rnd_cho_diff_t1_L1 + (1|Subject)'];
      
mdl_rnd4 = fitglme(T, f_rnd4, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace', 'OptimizerOptions', opts);
%%
f_rnd12 = ['Choice_top ~ ' reward_cho_terms ' + ' reward_nc_terms ' + ' ...
          regret_cho_terms ' + Rnd_cho_diff_t0_L1 + Rnd_cho_any_t0_L1 + (1|Subject)'];

mdl_rnd12 = fitglme(T, f_rnd12, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace', 'OptimizerOptions', opts);

%%
f_rnd13 = ['Choice_top ~ ' reward_cho_terms ' + ' reward_nc_terms ' + ' ...
          regret_cho_terms ' + Rnd_cho_diff_t0_L1 + Rnd_cho_same_t1_L1 + (1|Subject)'];

mdl_rnd13 = fitglme(T, f_rnd13, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace', 'OptimizerOptions', opts);
%%
f_rnd14 = ['Choice_top ~ ' reward_cho_terms ' + ' reward_nc_terms ' + ' ...
          regret_cho_terms ' + Rnd_cho_diff_t0_L1 + Rnd_cho_diff_t1_L1 + (1|Subject)'];

mdl_rnd14 = fitglme(T, f_rnd14, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace', 'OptimizerOptions', opts);
%%
f_rnd34 = ['Choice_top ~ ' reward_cho_terms ' + ' reward_nc_terms ' + ' ...
          regret_cho_terms ' + Rnd_cho_diff_t1_L1 + Rnd_cho_same_t1_L1 + (1|Subject)'];

mdl_rnd34 = fitglme(T, f_rnd34, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace', 'OptimizerOptions', opts);
%%
f_null = 'Choice_top ~ 1 + (1|Subject)';
mdl_null = fitglme(T, f_null, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace', 'OptimizerOptions', opts);
aic_null = mdl_null.ModelCriterion.AIC;
ll_null  = mdl_null.LogLikelihood;

fprintf('\n======== Null Model ========\n');
fprintf('AIC null:            %.2f\n', aic_null);
fprintf('LogLikelihood null:  %.2f\n', ll_null);

% comparing models with the null one
aic_values = [aic_null, ...
              mdl_reward_only.ModelCriterion.AIC, ...
              mdl_reward_regret.ModelCriterion.AIC, ...
              mdl_rnd1.ModelCriterion.AIC, ...
              mdl_rnd2.ModelCriterion.AIC, ...
              mdl_rnd3.ModelCriterion.AIC, ...
              mdl_rnd4.ModelCriterion.AIC, ...
              mdl_rnd12.ModelCriterion.AIC, ...
              mdl_rnd13.ModelCriterion.AIC, ...
              mdl_rnd14.ModelCriterion.AIC, ...
              mdl_rnd34.ModelCriterion.AIC];

model_names = {'Null', 'Reward-only', 'Reward+Regret', 'Rnd_cho_diff_t0','Rnd_cho_any_t0','Rnd_cho_same_t1_L1', 'Rnd_cho_diff_t1_L1', ...
               'Both_t0_any_&_diff', 't0_diff+t1_same', 't0_diff+t1_diff','Both_t1_same_diff'};

fprintf('\n======== comparing all models with Null ========\n');
fprintf('%-20s %-12s %-12s %-12s\n', 'Model', 'AIC', '?AIC_null', 'McFadden_R²');

ll_null_val = mdl_null.LogLikelihood;
for i = 1:length(aic_values)
    if i == 1
        ll_i = ll_null_val;
    else
        switch i
            case 2, ll_i = mdl_reward_only.LogLikelihood;
            case 3, ll_i = mdl_reward_regret.LogLikelihood;
            case 4, ll_i = mdl_rnd1.LogLikelihood;
            case 5, ll_i = mdl_rnd2.LogLikelihood;
            case 6, ll_i = mdl_rnd3.LogLikelihood;
            case 7, ll_i = mdl_rnd4.LogLikelihood;
            case 8, ll_i = mdl_rnd12.LogLikelihood;
            case 9, ll_i = mdl_rnd13.LogLikelihood;
            case 10, ll_i = mdl_rnd14.LogLikelihood;
            case 11, ll_i = mdl_rnd34.LogLikelihood;
        end
    end
    delta_aic  = aic_values(i) - aic_null;
    mcfadden_r2 = 1 - (ll_i / ll_null_val);

    fprintf('%-20s %-12.2f %-12.2f %-12.4f\n', ...
            model_names{i}, aic_values(i), delta_aic, mcfadden_r2);
end

%%
figure('Color','w','Position',[100 100 700 420]);

bar(1:length(aic_values), ...
    aic_values - aic_null, ...
    'FaceColor',[0.4 0.6 0.9]);

set(gca,'XTick',1:length(model_names));
set(gca,'XTickLabel',model_names);

ylabel('\DeltaAIC from Null (negative = better)');
title('Comparing models with Null model');

hold on;
plot(xlim,[0 0],'r--');  
hold off;

grid on;

set(gca,'XTick',1:length(model_names));
set(gca,'XTickLabel',model_names);

%% ============================================================
% 3 : individual analysis for random rewards
% ============================================================



%% ============================================================
%  4 : random-reward analysis with 1-2 variables &
%  interaction test: does random-reward misattribution moderate
%  the effect of Regret_chosen on choice?
% ============================================================

RND_VAR = 'Rnd_cho_diff_t0_L1';   % primary variable 
% RND_VAR2 = 'Rnd_cho_any_t0_L1'; % uncomment to add the mirror-image variable

subj_list  = unique(T.Subject);
n_subs     = length(subj_list);
subj_names = cell(n_subs, 1);
for i = 1:n_subs
    subj_names{i} = [subject_files{i}{1} '/' subject_files{i}{2}];
end

%% ============================================================
%  (A) GROUP-LEVEL: main effect of random-reward misattribution
% ============================================================
fprintf('======== (A) Main effect of %s ========\n', RND_VAR);

f_base  = ['Choice_top ~ ' reward_cho_terms ' + ' reward_nc_terms ' + ' regret_cho_terms ' + (1|Subject)'];
f_rnd   = [f_base(1:end-length(' + (1|Subject)')) ' + ' RND_VAR ' + (1|Subject)'];

mdl_base = fitglme(T, f_base, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace','OptimizerOptions',opts);
mdl_rnd  = fitglme(T, f_rnd,  'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace','OptimizerOptions',opts);

idx = strcmp(mdl_rnd.CoefficientNames, RND_VAR);
fprintf('b_%s = %.4f, SE = %.4f, p = %.5f\n', RND_VAR, ...
    mdl_rnd.Coefficients.Estimate(idx), mdl_rnd.Coefficients.SE(idx), mdl_rnd.Coefficients.pValue(idx));

ll_diff = mdl_rnd.LogLikelihood - mdl_base.LogLikelihood;
if ll_diff > 0
    lrt = 2*ll_diff; p_lrt = 1 - chi2cdf(lrt,1);
    fprintf('LRT vs base model: stat=%.3f, p=%.5f\n', lrt, p_lrt);
else
    fprintf('LRT: model with random-reward term did not improve fit.\n');
end

%% ============================================================
%  (B) does random-reward misattribution moderate
%      (interact with) the effect of comulative_regret on choice?
% ============================================================
RND_VAR = 'Rnd_cho_diff_t0_L1';
CUM_VAR = 'CumRegret_diff';
 
subj_list  = unique(T.Subject);
n_subs     = length(subj_list);
subj_names = cell(n_subs, 1);
for i = 1:n_subs
    subj_names{i} = [subject_files{i}{1} '/' subject_files{i}{2}];
end

f_main = ['Choice_top ~ ' reward_cho_terms ' + ' reward_nc_terms ' + ' ...
    CUM_VAR ' + ' RND_VAR ' + (1|Subject)'];
 
 
mdl_main = fitglme(T, f_main, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace','OptimizerOptions',opts);
disp(mdl_main.Coefficients);
%%
fprintf('\n======== (B) Interaction: %s x %s ========\n', CUM_VAR, RND_VAR);
 
f_interact = ['Choice_top ~ ' reward_cho_terms ' + ' reward_nc_terms ' + ' ...
    CUM_VAR ' + ' RND_VAR ' + ' CUM_VAR ':' RND_VAR ' + (1|Subject)'];
 
mdl_interact = fitglme(T, f_interact, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace','OptimizerOptions',opts);
disp(mdl_interact.Coefficients);
 
idx_int = strcmp(mdl_interact.CoefficientNames, 'Rnd_cho_diff_t0_L1:CumRegret_diff');
b_int = mdl_interact.Coefficients.Estimate(idx_int);
p_int = mdl_interact.Coefficients.pValue(idx_int);
idx_main_cum = strcmp(mdl_interact.CoefficientNames, CUM_VAR);
b_main_cum = mdl_interact.Coefficients.Estimate(idx_main_cum);
 
fprintf('\nInteraction: b = %.4f, p = %.5f\n', b_int, p_int);
if p_int < 0.05
    if sign(b_int) == sign(b_main_cum)
        fprintf('AMPLIFYING interaction: random-reward misattribution makes cumulative regret''s effect STRONGER.\n');
    else
        fprintf('ATTENUATING interaction: random-reward misattribution makes cumulative regret''s effect WEAKER.\n');
    end
else
    fprintf('No significant interaction: cumulative regret''s effect on choice does not depend on this random-reward channel.\n');
end
 
ll_diff = mdl_interact.LogLikelihood - mdl_main.LogLikelihood;
if ll_diff > 0
    lrt = 2*ll_diff; p_lrt = 1 - chi2cdf(lrt,1);
    fprintf('LRT (interaction vs main-effects model): stat=%.3f, p=%.5f\n', lrt, p_lrt);
end
 
%% ============================================================
%  (C) Per-subject: does the interaction replicate individually?
% ============================================================
fprintf('\n======== (C) Per-subject interaction coefficients ========\n');
fprintf('%-5s %-22s %-12s %-10s %-6s\n', 'No.','Subject','b_interact','p','sig');
fprintf('%s\n', repmat('-',1,58));

b_int_subj = nan(n_subs,1);
p_int_subj = nan(n_subs,1);

f_interact_fixed = f_interact(1:end-length(' + (1|Subject)'));

for i = 1:n_subs
    T_s = T(T.Subject == subj_list(i), :);
    if size(T_s,1) < 30, continue; end
    try
        mdl_s = fitglm(T_s, f_interact_fixed, 'Distribution','Binomial','Link','logit');
        idx_s = strcmp(mdl_s.CoefficientNames, 'Rnd_cho_diff_t0_L1:CumRegret_diff');
        if any(idx_s)
            b_int_subj(i) = mdl_s.Coefficients.Estimate(idx_s);
            p_int_subj(i) = mdl_s.Coefficients.pValue(idx_s);
            sig = 'ns';
            if p_int_subj(i) < 0.05, sig = '*'; end
            fprintf('%-5d %-22s %-12.4f %-10.4f %-6s\n', i, subj_names{i}, b_int_subj(i), p_int_subj(i), sig);
        end
    catch
        fprintf('%-5d %-22s ERROR/skipped\n', i, subj_names{i});
    end
end

valid = ~isnan(b_int_subj);
[~, p_grp, ~, stats_grp] = ttest(b_int_subj(valid));
fprintf('\nGroup t-test on per-subject interaction coefficients: mean=%.4f, t(%d)=%.3f, p=%.4f\n', ...
    mean(b_int_subj(valid)), stats_grp.df, stats_grp.tstat, p_grp);

%% =======================================
% D : random rwd and regret interaction ( no contigent rwd)
%%===========-============================-=======
fprintf('======== (A) Main effect of %s ========\n', RND_VAR);

f_base_new  = ['Choice_top ~ ' regret_cho_terms ' + (1|Subject)'];
f_rnd_new   = [f_base_new(1:end-length(' + (1|Subject)')) ' + ' RND_VAR ' + (1|Subject)'];

mdl_base_new = fitglme(T, f_base_new, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace','OptimizerOptions',opts);
mdl_rnd_new  = fitglme(T, f_rnd_new,  'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace','OptimizerOptions',opts);

idx = strcmp(mdl_rnd_new.CoefficientNames, RND_VAR);
fprintf('b_%s = %.4f, SE = %.4f, p = %.5f\n', RND_VAR, ...
    mdl_rnd_new.Coefficients.Estimate(idx), mdl_rnd_new.Coefficients.SE(idx), mdl_rnd_new.Coefficients.pValue(idx));

ll_diff_new = mdl_rnd_new.LogLikelihood - mdl_base_new.LogLikelihood;
if ll_diff_new > 0
    lrt = 2*ll_diff_new; p_lrt = 1 - chi2cdf(lrt,1);
    fprintf('LRT vs base model: stat=%.3f, p=%.5f\n', lrt, p_lrt);
else
    fprintf('LRT: model with random-reward term did not improve fit.\n');
end

%%
fprintf('\n======== (B) Interaction: %s x %s ========\n', CUM_VAR, RND_VAR);
 
f_interact_new = ['Choice_top ~  ' CUM_VAR ' + ' RND_VAR ' + ' CUM_VAR ':' RND_VAR ' + (1|Subject)'];
 
mdl_interact_new = fitglme(T, f_interact_new, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace','OptimizerOptions',opts);
disp(mdl_interact_new.Coefficients);
 
idx_int = strcmp(mdl_interact_new.CoefficientNames, 'Rnd_cho_diff_t0_L1:CumRegret_diff');
b_int = mdl_interact_new.Coefficients.Estimate(idx_int);
p_int = mdl_interact_new.Coefficients.pValue(idx_int);
idx_main_cum = strcmp(mdl_interact_new.CoefficientNames, CUM_VAR);
b_main_cum = mdl_interact_new.Coefficients.Estimate(idx_main_cum);
 
fprintf('\nInteraction: b = %.4f, p = %.5f\n', b_int, p_int);
if p_int < 0.05
    if sign(b_int) == sign(b_main_cum)
        fprintf('amplyfing interaction: random-reward misattribution makes cumulative regret''s effect stronger.\n');
    else
        fprintf('attenuating interaction: random-reward misattribution makes cumulative regret''s effect weaker.\n');
    end
else
    fprintf('No significant interaction: cumulative regret''s effect on choice does not depend on this random-reward channel.\n');
end
 
ll_diff = mdl_interact_new.LogLikelihood -mdl_base_new.LogLikelihood;
if ll_diff > 0
    lrt = 2*ll_diff; p_lrt = 1 - chi2cdf(lrt,1);
    fprintf('LRT (interaction vs main effects model): stat=%.3f, p=%.5f\n', lrt, p_lrt);
end



%% ============================================================
%  Individual analysis for each variable
% ============================================================
RND_VAR = 'Rnd_cho_diff_t0_L1';
CUM_VAR = 'CumRegret_diff';

model_names_list = { ...
    'Chosen_Reward_only', ...
    'Not_Chosen Reward_only', ...
    'Regret_only', ...
    'Cumulative_Regret_only', ...
    'Cumulative_Regret_trial_interaction', ...
    'Rnd_cho_diff_t0'};

model_formulas = { ...
    ['Choice_top ~ ' reward_cho_terms ], ...
    ['Choice_top ~ '  reward_nc_terms ], ...
    ['Choice_top ~ ' regret_cho_terms], ...
    ['Choice_top ~ ' CUM_VAR], ...
    ['Choice_top ~ ' CUM_VAR ':Trial_z'], ...
    ['Choice_top ~ ' RND_VAR ]};

%%
focal_preds = { ...
    'Reward_chosen_L1', ...
    'Reward_notchosen_L1', ...
    'Regret_chosen_L1', ...     
    'CumRegret_diff', ...        
    'CumRegret_diff:Trial_z', ...     
    'Rnd_cho_diff_t0_L1'};     
n_models  = length(model_names_list);
subj_list = unique(T.Subject);
n_subs    = length(subj_list);

%% 
all_betas = nan(n_subs, n_models);
all_pvals = nan(n_subs, n_models);
grp_mean  = nan(1, n_models);
grp_pval  = nan(1, n_models);
grp_tstat = nan(1, n_models);
grp_df    = nan(1, n_models);

subj_names = cell(n_subs, 1);
for i = 1:n_subs
    subj_names{i} = [subject_files{i}{1} '/' subject_files{i}{2}];
end

for m = 1:n_models
    fprintf('\n======== %s  |  focal: %s ========\n', ...
            model_names_list{m}, focal_preds{m});
    fprintf('%-5s %-22s %-10s %-10s %-6s\n', ...
            'No.','Subject','beta','p','sig');
    fprintf('%s\n', repmat('-',1,55));

    for i = 1:n_subs
        T_s = T(T.Subject == subj_list(i), :);
        if size(T_s,1) < 30, continue; end

        try
            mdl_s = fitglm(T_s, model_formulas{m}, ...
                           'Distribution','Binomial','Link','logit');

            idx  = strcmp(mdl_s.CoefficientNames, focal_preds{m});
            if ~any(idx), continue; end

            beta = mdl_s.Coefficients.Estimate(idx);
            p_w  = mdl_s.Coefficients.pValue(idx);

            all_betas(i,m) = beta;
            all_pvals(i,m) = p_w;

            if p_w < 0.001,     sig = '***';
            elseif p_w < 0.01,  sig = '**';
            elseif p_w < 0.05,  sig = '*';
            else                sig = 'ns';
            end

            fprintf('%-5d %-22s %-10.4f %-10.4f %-6s\n', ...
                    i, subj_names{i}, beta, p_w, sig);
        catch
            fprintf('%-5d %-22s ERROR\n', i, subj_names{i});
        end
    end

    %% t-test 
    valid_m = ~isnan(all_betas(:,m));
    if sum(valid_m) < 3, continue; end

    [~, p_g, ~, st] = ttest(all_betas(valid_m,m));
    grp_mean(m)  = mean(all_betas(valid_m,m));
    grp_pval(m)  = p_g;
    grp_tstat(m) = st.tstat;
    grp_df(m)    = st.df;

    fprintf('\nGroup: mean=%.4f, t(%d)=%.3f, p=%.4f\n', ...
            grp_mean(m), grp_df(m), grp_tstat(m), grp_pval(m));
end

%%
fprintf('\n========  Group-level t-test ========\n');
fprintf('%-22s %-12s %-10s %-10s %-10s %-6s\n', ...
        'Model','Focal','Mean_beta','t','p','sig');
fprintf('%s\n', repmat('-',1,72));

for m = 1:n_models
    if grp_pval(m) < 0.001,     sig = '***';
    elseif grp_pval(m) < 0.01,  sig = '**';
    elseif grp_pval(m) < 0.05,  sig = '*';
    else              sig = 'ns';
    end
    fprintf('%-22s %-12s %-10.4f %-10.3f %-10.4f %-6s\n', ...
            model_names_list{m}, focal_preds{m}, ...
            grp_mean(m), grp_tstat(m), grp_pval(m), sig);
end


%% plot

figure('Color','w','Position',[50 50 1400 500]);

for m = 1:n_models
    subplot(1, n_models, m);

    betas_m = all_betas(:,m);
    valid_m = ~isnan(betas_m);

    %%
    colors = zeros(n_subs, 3);
    for i = 1:n_subs
        if isnan(betas_m(i))
            colors(i,:) = [0.8 0.8 0.8];
        elseif betas_m(i) < 0
            colors(i,:) = [0.3 0.5 0.9];   
        else
            colors(i,:) = [0.9 0.5 0.3];  
        end
    end

    hold on;
    for i = 1:n_subs
        if ~isnan(betas_m(i))
            bar(i, betas_m(i), 0.7, 'FaceColor', colors(i,:), 'EdgeColor','none');
            if all_pvals(i,m) < 0.05
                text(i, betas_m(i) + sign(betas_m(i))*0.0003, '*', ...
                     'HorizontalAlignment','center','FontSize',10,'Color','k');
            end
        end
    end

    %%
    ax_m = gca;
    xl   = [0.5, n_subs+0.5];
    plot(xl, [0 0], 'k-', 'LineWidth', 0.8);

    %% 
    if ~isnan(grp_mean(m))
        plot(xl, [grp_mean(m) grp_mean(m)], 'r--', 'LineWidth', 1.5);
    end

    set(ax_m, 'XTick', 1:5:n_subs);
    xlabel('Subject');
    ylabel('beta');
    title({model_names_list{m}, ...
           sprintf('focal: %s', strrep(focal_preds{m},'_','\_')), ...
           sprintf('mean=%.4f, p=%.3f', grp_mean(m), grp_pval(m))}, ...
          'FontSize', 8);
    grid on; box on;
    hold off;
end



%% ============================================================
% 5 : Reward & Regret decay comparison
% ============================================================
f_reward = ['Choice_top ~ ' reward_cho_terms ' + ' ...
            reward_nc_terms ' + (1|Subject)'];

mdl_reward = fitglme(T, f_reward, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace','OptimizerOptions',opts);

fprintf('\n======== Model 1: Reward only (L1-L6) ========\n');
disp(mdl_reward.Coefficients);
fprintf('AIC = %.2f\n', mdl_reward.ModelCriterion.AIC);

%% ---- Plot 1: decay of reward coefficients ----
b_cho = nan(6,1);  se_cho = nan(6,1);
b_nc  = nan(6,1);  se_nc  = nan(6,1);

for k = 1:6
    idx = strcmp(mdl_reward.CoefficientNames, ['Reward_chosen_L' num2str(k)]);
    if any(idx)
        b_cho(k)  = mdl_reward.Coefficients.Estimate(idx);
        se_cho(k) = mdl_reward.Coefficients.SE(idx);
    end
    idx = strcmp(mdl_reward.CoefficientNames, ['Reward_notchosen_L' num2str(k)]);
    if any(idx)
        b_nc(k)  = mdl_reward.Coefficients.Estimate(idx);
        se_nc(k) = mdl_reward.Coefficients.SE(idx);
    end
end

figure('Color','w','Position',[100 100 600 400]);
hold on;

% Reward chosen
h1 = errorbar(1:6, b_cho, se_cho, 'b-o', ...
    'LineWidth',2, 'MarkerSize',7);

% Reward not chosen
h2 = errorbar(1:6, b_nc, se_nc, 'r-s', ...
    'LineWidth',2, 'MarkerSize',7);

% Zero reference line
plot([0.5 6.5], [0 0], 'k--', 'LineWidth', 1);

xlabel('Lag');
ylabel('\beta (logit)');

set(gca, 'XTick', 1:6);
set(gca, 'XTickLabel', lags);

xlim([0.5 6.5]);

title('Model 1: Reward coefficients across lags');

legend([h1 h2], ...
    {'Reward chosen','Reward not chosen'}, ...
    'Location','NorthEast');

grid on;
box on;
hold off;

%% ============================================================
% Model 2: Regret only 
% ============================================================
f_regret = ['Choice_top ~ ' regret_cho_terms ' + (1|Subject)'];

mdl_regret = fitglme(T, f_regret, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace','OptimizerOptions',opts);

fprintf('\n======== Model 2: Regret only (L1-L6) ========\n');
disp(mdl_regret.Coefficients);
fprintf('AIC = %.2f\n', mdl_regret.ModelCriterion.AIC);

%% ---- Plot 2: decay of regret coefficients ----
b_reg = nan(6,1); se_reg = nan(6,1);

for k = 1:6
    idx = strcmp(mdl_regret.CoefficientNames, ['Regret_chosen_L' num2str(k)]);
    if any(idx)
        b_reg(k)  = mdl_regret.Coefficients.Estimate(idx);
        se_reg(k) = mdl_regret.Coefficients.SE(idx);
    end
end

figure('Color','w','Position',[100 100 600 400]);
hold on;

% Regret chosen
h1 = errorbar(1:6, b_reg, se_reg, 'b-o', ...
    'LineWidth',2, 'MarkerSize',7);

% Zero reference line 
plot([0.5 6.5], [0 0], 'k--', 'LineWidth', 1);

xlabel('Lag');
ylabel('\beta (logit)');

set(gca,'XTick',1:6);
set(gca,'XTickLabel',lags);

xlim([0.5 6.5]);

title('Model 2: Regret coefficients across lags');

legend(h1, 'Regret chosen', ...
    'Location', 'NorthEast');

grid on;
box on;
hold off;

%% ===========================================================
% Model both:  Reward + Regret 
% ============================================================
f_both = ['Choice_top ~ ' reward_cho_terms ' + ' reward_nc_terms ' + ' ...
          regret_cho_terms ' + (1|Subject)'];

mdl_both = fitglme(T, f_both, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace','OptimizerOptions',opts);

fprintf('\n======== Model 3: Reward + Regret (L1-L6) ========\n');
disp(mdl_both.Coefficients);
fprintf('AIC = %.2f\n', mdl_both.ModelCriterion.AIC);

%% ---- Plot 3 ----
b_cho2  = nan(6,1); se_cho2 = nan(6,1);
b_nc2   = nan(6,1); se_nc2  = nan(6,1);
b_reg2  = nan(6,1); se_reg2 = nan(6,1);

for k = 1:6
    for pair = {{'Reward_chosen_L','cho2'},{'Reward_notchosen_L','nc2'}, ...
                {'Regret_chosen_L','reg2'}}
        vname = [pair{1}{1} num2str(k)];
        vvar  = pair{1}{2};
        idx   = strcmp(mdl_both.CoefficientNames, vname);
        if any(idx)
            eval(['b_' vvar '(' num2str(k) ') = mdl_both.Coefficients.Estimate(idx);']);
            eval(['se_' vvar '(' num2str(k) ') = mdl_both.Coefficients.SE(idx);']);
        end
    end
end

figure('Color','w','Position',[100 100 700 420]);
hold on;

% Reward chosen
h1 = errorbar(1:6, b_cho2, se_cho2, 'b-o', ...
    'LineWidth',2, 'MarkerSize',6);

% Reward not chosen
h2 = errorbar(1:6, b_nc2, se_nc2, 'b--s', ...
    'LineWidth',2, 'MarkerSize',6);

% Regret chosen
h3 = errorbar(1:6, b_reg2, se_reg2, 'r-o', ...
    'LineWidth',2, 'MarkerSize',6);


% Zero reference line
plot([0.5 6.5], [0 0], 'k--', 'LineWidth', 1);

xlabel('Lag');
ylabel('\beta (logit)');

set(gca,'XTick',1:6);
set(gca,'XTickLabel',lags);

xlim([0.5 6.5]);

title('Model 3: Reward + Regret coefficients across lags');

legend([h1 h2 h3], ...
    {'Reward chosen', ...
     'Reward not chosen', ...
     'Regret chosen'}, ...
    'Location','NorthEast');

grid on;
box on;
hold off;

%% ---- AIC of these 3 models ---
aic_null_val = mdl_null.ModelCriterion.AIC;
aics = [aic_null_val, mdl_reward.ModelCriterion.AIC, ...
        mdl_regret.ModelCriterion.AIC, mdl_both.ModelCriterion.AIC];
names_aic = {'Null','Reward','Regret','Both'};

fprintf('\n======== AIC comparison ========\n');
fprintf('%-15s %-12s %-12s\n','Model','AIC','?AIC_null');
for i = 1:4
    fprintf('%-15s %-12.2f %-12.2f\n', names_aic{i}, aics(i), aics(i)-aic_null_val);
end

figure('Color','w','Position',[100 100 500 380]);
bar(1:4, aics - aic_null_val,'FaceColor',[0.4 0.6 0.8]);
set(gca,'XTickLabel',names_aic);
ylabel('\DeltaAIC ?? Null (negative = better)');
title('Model Comparison: AIC');
grid on;
 
%% ============================================================
%   regret vs relief 
%  Question: is |beta_Regret_L1| significantly LARGER than
%  |beta_Relief_L1|, controlling for the same raw reward values?
%  Two convergent tests:
%   (a) Group-level Wald contrast on the mixed model 
%   (b) Per-subject paired test on |beta| 


%% ---- Model : Reward + Regret + Relief (group mixed model) ----
f_reg_rel = ['Choice_top ~ ' reward_cho_terms ' + ' reward_nc_terms ' + ' ...
             regret_cho_terms ' + ' relief_nc_terms ' + (1|Subject)'];
 
mdl_reg_rel = fitglme(T, f_reg_rel, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace','OptimizerOptions',opts);
 
fprintf('\n======== Model 4: Reward + Regret + Relief (L1-L6) ========\n');
disp(mdl_reg_rel.Coefficients);
fprintf('AIC = %.2f\n', mdl_reg_rel.ModelCriterion.AIC);
 
%% ---- Plot 4: decay of regret vs relief coefficients side by side ----
b_reg4 = nan(6,1); se_reg4 = nan(6,1);
b_rel4 = nan(6,1); se_rel4 = nan(6,1);
for k = 1:6
    idx = strcmp(mdl_reg_rel.CoefficientNames, ['Regret_chosen_L' num2str(k)]);
    if any(idx)
        b_reg4(k)  = mdl_reg_rel.Coefficients.Estimate(idx);
        se_reg4(k) = mdl_reg_rel.Coefficients.SE(idx);
    end
    idx = strcmp(mdl_reg_rel.CoefficientNames, ['Relief_notchosen_L' num2str(k)]);
    if any(idx)
        b_rel4(k)  = mdl_reg_rel.Coefficients.Estimate(idx);
        se_rel4(k) = mdl_reg_rel.Coefficients.SE(idx);
    end
end
 
figure('Color','w','Position',[100 100 650 420]);
hold on;
h1 = errorbar(1:6, b_reg4, se_reg4, 'r-o', 'LineWidth',2, 'MarkerSize',7);
h2 = errorbar(1:6, b_rel4, se_rel4, 'b-s', 'LineWidth',2, 'MarkerSize',7);
plot([0.5 6.5],[0 0],'k--','LineWidth',1);
xlabel('Lag'); ylabel('\beta (logit)');
set(gca,'XTick',1:6,'XTickLabel',lags);
xlim([0.5 6.5]);
title('Regret vs Relief coefficients across lags');
legend([h1 h2], {'Regret chosen','Relief not-chosen'}, 'Location','NorthEast');
grid on; box on; hold off;
 
figure('Color','w','Position',[100 100 650 420]);
hold on;
h1 = errorbar(1:6, abs(b_reg4), se_reg4, 'r-o', 'LineWidth',2, 'MarkerSize',7);
h2 = errorbar(1:6, abs(b_rel4), se_rel4, 'b-s', 'LineWidth',2, 'MarkerSize',7);
xlabel('Lag'); ylabel('|\beta| (logit)');
set(gca,'XTick',1:6,'XTickLabel',lags);
xlim([0.5 6.5]);
title('Magnitude comparison: |Regret| vs |Relief| across lags');
legend([h1 h2], {'|Regret chosen|','|Relief not-chosen|'}, 'Location','NorthEast');
grid on; box on; hold off;
 
%% ---- (a) Group-level Wald contrast test: |b_Regret_L1| vs |b_Relief_L1| ----
fprintf('\n======== (a) Group-level Wald contrast: |Regret_L1| vs |Relief_L1| ========\n');
idx_reg1 = strcmp(mdl_reg_rel.CoefficientNames, 'Regret_chosen_L1');
idx_rel1 = strcmp(mdl_reg_rel.CoefficientNames, 'Relief_notchosen_L1');
 
b_reg1 = mdl_reg_rel.Coefficients.Estimate(idx_reg1);
b_rel1 = mdl_reg_rel.Coefficients.Estimate(idx_rel1);
CovB   = mdl_reg_rel.CoefficientCovariance;
var_reg1  = CovB(idx_reg1, idx_reg1);
var_rel1  = CovB(idx_rel1, idx_rel1);
cov_regrel = CovB(idx_reg1, idx_rel1);
 
% sign convention: regret typically pushes away from choosing (negative),
% relief typically pushes TOWARD choosing (positive) - so a same-scale
% comparison of MAGNITUDE is |b_reg1| - |b_rel1|.
s_reg = sign(b_reg1); s_rel = sign(b_rel1);
 
% Sign-agnostic delta-method SE for |b_reg1| - |b_rel1|:
% d(|x|)/dx = sign(x), so contrast c = |b_reg1| - |b_rel1|
c = abs(b_reg1) - abs(b_rel1);
grad = [s_reg; -s_rel];  % gradient wrt [b_reg1; b_rel1]
Cov2 = [var_reg1 cov_regrel; cov_regrel var_rel1];
se_c = sqrt(grad' * Cov2 * grad);
z_c  = c / se_c;
p_c  = 2*(1 - normcdf(abs(z_c)));
 
fprintf('b_Regret_L1 = %.4f, b_Relief_L1 = %.4f\n', b_reg1, b_rel1);
fprintf('|Regret_L1| - |Relief_L1| = %.4f, SE = %.4f, z = %.3f, p = %.5f\n', c, se_c, z_c, p_c);
if p_c < 0.05 && c > 0
    fprintf('Regret has a significantly LARGER magnitude effect than Relief at L1 (loss-aversion pattern).\n');
elseif p_c < 0.05 && c < 0
    fprintf('Relief has a significantly LARGER magnitude effect than Regret at L1 (opposite of loss-aversion).\n');
else
    fprintf('No significant asymmetry between Regret and Relief magnitude at L1.\n');
end
 
%% ---- (b) Per-subject paired test on |beta| ----
fprintf('\n======== (b) Per-subject paired test: |beta_Regret_L1| vs |beta_Relief_L1| ========\n');
subj_list = unique(T.Subject);
n_subs    = length(subj_list);
beta_reg_subj = nan(n_subs,1);
beta_rel_subj = nan(n_subs,1);
 
for i = 1:n_subs
    T_s = T(T.Subject == subj_list(i), :);
    if size(T_s,1) < 30, continue; end
    try
        mdl_s = fitglm(T_s, f_reg_rel(1:end-length(' + (1|Subject)')), ...
                       'Distribution','Binomial','Link','logit');
        idx1 = strcmp(mdl_s.CoefficientNames, 'Regret_chosen_L1');
        idx2 = strcmp(mdl_s.CoefficientNames, 'Relief_notchosen_L1');
        if any(idx1), beta_reg_subj(i) = mdl_s.Coefficients.Estimate(idx1); end
        if any(idx2), beta_rel_subj(i) = mdl_s.Coefficients.Estimate(idx2); end
    catch
        % leave as NaN
    end
end
 
valid_pair = ~isnan(beta_reg_subj) & ~isnan(beta_rel_subj);
abs_reg = abs(beta_reg_subj(valid_pair));
abs_rel = abs(beta_rel_subj(valid_pair));
 
[~, p_paired, ~, stats_paired] = ttest(abs_reg, abs_rel);
fprintf('N subjects with both estimates = %d\n', sum(valid_pair));
fprintf('Mean |beta_Regret_L1| = %.4f, Mean |beta_Relief_L1| = %.4f\n', mean(abs_reg), mean(abs_rel));
fprintf('Paired t-test: t(%d) = %.3f, p = %.5f\n', stats_paired.df, stats_paired.tstat, p_paired);
if p_paired < 0.05 && mean(abs_reg) > mean(abs_rel)
    fprintf('Confirms: Regret magnitude > Relief magnitude across subjects (loss-aversion).\n');
elseif p_paired < 0.05
    fprintf('Relief magnitude > Regret magnitude across subjects.\n');
else
    fprintf('No significant per-subject asymmetry.\n');
end
 
%% ---- plot: per-subject paired comparison ----
figure('Color','w','Position',[100 100 500 450]);
hold on;
for i = 1:length(abs_reg)
    plot([1 2], [abs_reg(i) abs_rel(i)], '-', 'Color',[0.7 0.7 0.7]);
end
plot(ones(size(abs_reg)), abs_reg, 'ro', 'MarkerFaceColor','r', 'MarkerSize',6);
plot(2*ones(size(abs_rel)), abs_rel, 'bo', 'MarkerFaceColor','b', 'MarkerSize',6);
plot([1 2], [mean(abs_reg) mean(abs_rel)], 'k-', 'LineWidth', 3);
set(gca,'XTick',[1 2],'XTickLabel',{'|Regret_{L1}|','|Relief_{L1}|'});
xlim([0.5 2.5]);
ylabel('|\beta|');
title({'Per-subject Regret vs Relief magnitude', ...
    sprintf('paired t(%d)=%.2f, p=%.4f', stats_paired.df, stats_paired.tstat, p_paired)});
grid on; box on; hold off;

%% ============================================================
%   why does Regret_chosen flip sign across lags?
% ============================================================
%% ---- (1) Correlation / VIF among the 6 Regret_chosen lags ----
regret_lag_names = strcat('Regret_chosen_', lags);
X_reg = T{:, regret_lag_names};

fprintf('=== Correlation matrix: Regret_chosen_L1..L6 ===\n');
R_reg = corr(X_reg, 'rows','complete');
disp(array2table(R_reg, 'VariableNames', regret_lag_names, 'RowNames', regret_lag_names));

fprintf('\n=== VIF for each Regret_chosen lag (>5 borderline, >10 severe) ===\n');
for i = 1:6
    y_vif = X_reg(:,i);
    X_vif = X_reg(:, setdiff(1:6, i));
    mdl_vif = fitlm(X_vif, y_vif);
    vif_i = 1/(1-mdl_vif.Rsquared.Ordinary);
    flag = '';
    if vif_i > 10, flag = '  <-- SEVERE';
    elseif vif_i > 5, flag = '  <-- borderline';
    end
    fprintf('%-20s VIF = %.2f%s\n', regret_lag_names{i}, vif_i, flag);
end

%% ---- (2) Progressive lag inclusion  ----- 
fprintf('\n=== Progressive lag inclusion: does adding later lags destabilize earlier ones? ===\n');
fprintf('%-25s', 'Lags in model');
for k = 1:6, fprintf('%-10s', ['b_L' num2str(k)]); end
fprintf('\n');

for k_max = 1:6
    terms = strjoin(regret_lag_names(1:k_max), ' + ');
    f_prog = ['Choice_top ~ ' terms ' + (1|Subject)'];
    mdl_prog = fitglme(T, f_prog, 'Distribution','Binomial','Link','logit', ...
        'FitMethod','Laplace','OptimizerOptions',opts);

    fprintf('%-25s', ['L1..L' num2str(k_max)]);
    for k = 1:6
        if k <= k_max
            idx = strcmp(mdl_prog.CoefficientNames, ['Regret_chosen_L' num2str(k)]);
            fprintf('%-10.4f', mdl_prog.Coefficients.Estimate(idx));
        else
            fprintf('%-10s', '-');
        end
    end
    fprintf('\n');
end
fprintf(['\nIf b_L1 changes sign or magnitude substantially as later lags are added, ' ...
    'that confirms the flips are a collinearity/suppression artifact, not real lag-6 signal.\n']);

%% ============================================================
%  the flip in Model 4 may come from Regret x Relief (or Reward)
%  interaction. #VIF for regret & relief
% ============================================================

regret_lag_names = strcat('Regret_chosen_', lags);
relief_lag_names = strcat('Relief_notchosen_', lags);

%% ---- (1) Same-lag correlation: Regret_L_k vs Relief_L_k ----
fprintf('=== Correlation: Regret_chosen_Lk vs Relief_notchosen_Lk (same k) ===\n');
for k = 1:6
    r = corr(T.(regret_lag_names{k}), T.(relief_lag_names{k}), 'rows','complete');
    fprintf('L%d: r = %.3f\n', k, r);
end

%% ---- (2) VIF for each Regret lag, now against ALL Relief lags too ----
X_both = T{:, [regret_lag_names, relief_lag_names]};
both_names = [regret_lag_names, relief_lag_names];
fprintf('\n=== VIF for Regret_chosen lags, controlling for ALL Relief lags ===\n');
for i = 1:6   % just the regret columns (first 6)
    y_vif = X_both(:,i);
    X_vif = X_both(:, setdiff(1:12, i));
    mdl_vif = fitlm(X_vif, y_vif);
    vif_i = 1/(1-mdl_vif.Rsquared.Ordinary);
    flag = '';
    if vif_i > 10, flag = '  <-- SEVERE';
    elseif vif_i > 5, flag = '  <-- borderline';
    end
    fprintf('%-20s VIF = %.2f%s\n', regret_lag_names{i}, vif_i, flag);
end

%% ---- (3) Progressive test: add Relief lags ONE AT A TIME to the
%          full Regret L1-L6 model, watch Regret's coefficients ----
fprintf('\n=== Does adding Relief lags destabilize Regret coefficients? ===\n');
fprintf('%-25s', 'Relief lags added');
for k = 1:6, fprintf('%-10s', ['bReg_L' num2str(k)]); end
fprintf('\n');

regret_terms_all = strjoin(regret_lag_names, ' + ');

for k_max = 0:6
    if k_max == 0
        f_prog = ['Choice_top ~ ' regret_terms_all ' + (1|Subject)'];
        label = 'none';
    else
        relief_terms = strjoin(relief_lag_names(1:k_max), ' + ');
        f_prog = ['Choice_top ~ ' regret_terms_all ' + ' relief_terms ' + (1|Subject)'];
        label = ['L1..L' num2str(k_max)];
    end
    mdl_prog = fitglme(T, f_prog, 'Distribution','Binomial','Link','logit', ...
        'FitMethod','Laplace','OptimizerOptions',opts);

    fprintf('%-25s', label);
    for k = 1:6
        idx = strcmp(mdl_prog.CoefficientNames, ['Regret_chosen_L' num2str(k)]);
        fprintf('%-10.4f', mdl_prog.Coefficients.Estimate(idx));
    end
    fprintf('\n');
end
fprintf(['\nWatch which Relief lag, once added, first causes a Regret lag to flip sign - ' ...
    'that pinpoints exactly which pair is responsible.\n']);

%% ---- (4) Also check Reward terms as a possible third contributor ----
fprintf('\n=== VIF for Regret lags controlling for Relief AND Reward (all 24 lag terms) ===\n');
reward_cho_names = strcat('Reward_chosen_', lags);
reward_nc_names  = strcat('Reward_notchosen_', lags);
X_all = T{:, [regret_lag_names, relief_lag_names, reward_cho_names, reward_nc_names]};
for i = 1:6
    y_vif = X_all(:,i);
    X_vif = X_all(:, setdiff(1:24, i));
    mdl_vif = fitlm(X_vif, y_vif);
    vif_i = 1/(1-mdl_vif.Rsquared.Ordinary);
    flag = '';
    if vif_i > 10, flag = '  <-- SEVERE';
    elseif vif_i > 5, flag = '  <-- borderline';
    end
    fprintf('%-20s VIF = %.2f%s\n', regret_lag_names{i}, vif_i, flag);
end



%% ============================================================
%  FINAL CHECK: #VIF regret & Reward
% ============================================================

regret_lag_names = strcat('Regret_chosen_', lags);
relief_lag_names = strcat('Relief_notchosen_', lags);
reward_cho_names = strcat('Reward_chosen_', lags);
reward_nc_names  = strcat('Reward_notchosen_', lags);

regret_terms_all = strjoin(regret_lag_names, ' + ');
relief_terms_all = strjoin(relief_lag_names, ' + ');

fprintf('=== Does adding Reward_chosen/notchosen lags flip Regret signs? ===\n');
fprintf('%-25s', 'Reward lags added');
for k = 1:6, fprintf('%-10s', ['bReg_L' num2str(k)]); end
fprintf('\n');

for k_max = 0:6
    if k_max == 0
        f_prog = ['Choice_top ~ ' regret_terms_all ' + ' relief_terms_all ' + (1|Subject)'];
        label = 'none (baseline)';
    else
        rc_terms = strjoin(reward_cho_names(1:k_max), ' + ');
        rn_terms = strjoin(reward_nc_names(1:k_max), ' + ');
        f_prog = ['Choice_top ~ ' regret_terms_all ' + ' relief_terms_all ' + ' ...
                  rc_terms ' + ' rn_terms ' + (1|Subject)'];
        label = ['L1..L' num2str(k_max)];
    end
    mdl_prog = fitglme(T, f_prog, 'Distribution','Binomial','Link','logit', ...
        'FitMethod','Laplace','OptimizerOptions',opts);

    fprintf('%-25s', label);
    for k = 1:6
        idx = strcmp(mdl_prog.CoefficientNames, ['Regret_chosen_L' num2str(k)]);
        fprintf('%-10.4f', mdl_prog.Coefficients.Estimate(idx));
    end
    fprintf('\n');
end

fprintf(['\nIf signs flip here (especially matching the pattern from the original ' ...
    'Model 4: L1 stays negative, L3+ turns positive), this confirms Reward_chosen is ' ...
    'the structural source - because Regret_chosen is mathematically derived from it ' ...
    '(max(0, notchosen-chosen)), and this nonlinear link is not fully captured by linear VIF.\n']);

%% = similar to line 994 but without reward = 
% ===== 6 : Model :  Regret & Reward   ====
% ===========================================
f_reg_rel_1 = ['Choice_top ~ '  regret_cho_terms ' + ' relief_nc_terms ' + (1|Subject)'];
 
mdl_reg_rel_1 = fitglme(T, f_reg_rel_1, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace','OptimizerOptions',opts);
 
fprintf('\n======== Model 4:  Regret + Relief (L1-L6) ========\n');
disp(mdl_reg_rel_1.Coefficients);
fprintf('AIC = %.2f\n', mdl_reg_rel_1.ModelCriterion.AIC);

%% ---- Plot n: decay of regret vs relief coefficients side by side (without reward model) ----
b_reg4 = nan(6,1); se_reg4 = nan(6,1);
b_rel4 = nan(6,1); se_rel4 = nan(6,1);
for k = 1:6
    idx = strcmp(mdl_reg_rel_1.CoefficientNames, ['Regret_chosen_L' num2str(k)]);
    if any(idx)
        b_reg4(k)  = mdl_reg_rel_1.Coefficients.Estimate(idx);
        se_reg4(k) = mdl_reg_rel_1.Coefficients.SE(idx);
    end
    idx = strcmp(mdl_reg_rel_1.CoefficientNames, ['Relief_notchosen_L' num2str(k)]);
    if any(idx)
        b_rel4(k)  = mdl_reg_rel_1.Coefficients.Estimate(idx);
        se_rel4(k) = mdl_reg_rel_1.Coefficients.SE(idx);
    end
end
 
figure('Color','w','Position',[100 100 650 420]);
hold on;
h1 = errorbar(1:6, b_reg4, se_reg4, 'r-o', 'LineWidth',2, 'MarkerSize',7);
h2 = errorbar(1:6, b_rel4, se_rel4, 'b-s', 'LineWidth',2, 'MarkerSize',7);
plot([0.5 6.5],[0 0],'k--','LineWidth',1);
xlabel('Lag'); ylabel('\beta (logit)');
set(gca,'XTick',1:6,'XTickLabel',lags);
xlim([0.5 6.5]);
title('Regret vs Relief coefficients across lags');
legend([h1 h2], {'Regret chosen','Relief not-chosen'}, 'Location','NorthEast');
grid on; box on; hold off;
 
figure('Color','w','Position',[100 100 650 420]);
hold on;
h1 = errorbar(1:6, abs(b_reg4), se_reg4, 'r-o', 'LineWidth',2, 'MarkerSize',7);
h2 = errorbar(1:6, abs(b_rel4), se_rel4, 'b-s', 'LineWidth',2, 'MarkerSize',7);
xlabel('Lag'); ylabel('|\beta| (logit)');
set(gca,'XTick',1:6,'XTickLabel',lags);
xlim([0.5 6.5]);
title('Magnitude comparison: |Regret| vs |Relief| across lags');
legend([h1 h2], {'|Regret chosen|','|Relief not-chosen|'}, 'Location','NorthEast');
grid on; box on; hold off;
 
%% ---- (a) Group-level Wald contrast test: |b_Regret_L1| vs |b_Relief_L1| ----
fprintf('\n======== (a) Group-level Wald contrast: |Regret_L1| vs |Relief_L1| ========\n');
idx_reg1 = strcmp(mdl_reg_rel_1.CoefficientNames, 'Regret_chosen_L1');
idx_rel1 = strcmp(mdl_reg_rel_1.CoefficientNames, 'Relief_notchosen_L1');
 
b_reg1 = mdl_reg_rel_1.Coefficients.Estimate(idx_reg1);
b_rel1 = mdl_reg_rel_1.Coefficients.Estimate(idx_rel1);
CovB   = mdl_reg_rel_1.CoefficientCovariance;
var_reg1  = CovB(idx_reg1, idx_reg1);
var_rel1  = CovB(idx_rel1, idx_rel1);
cov_regrel = CovB(idx_reg1, idx_rel1);
 
% sign convention: regret typically pushes AWAY from choosing (negative),
% relief typically pushes TOWARD choosing (positive) - so a same-scale
% comparison of MAGNITUDE is |b_reg1| - |b_rel1|.
s_reg = sign(b_reg1); s_rel = sign(b_rel1);
 
% Sign-agnostic delta-method SE for |b_reg1| - |b_rel1|:
% d(|x|)/dx = sign(x), so contrast c = |b_reg1| - |b_rel1|
c = abs(b_reg1) - abs(b_rel1);
grad = [s_reg; -s_rel];  % gradient wrt [b_reg1; b_rel1]
Cov2 = [var_reg1 cov_regrel; cov_regrel var_rel1];
se_c = sqrt(grad' * Cov2 * grad);
z_c  = c / se_c;
p_c  = 2*(1 - normcdf(abs(z_c)));
 
fprintf('b_Regret_L1 = %.4f, b_Relief_L1 = %.4f\n', b_reg1, b_rel1);
fprintf('|Regret_L1| - |Relief_L1| = %.4f, SE = %.4f, z = %.3f, p = %.5f\n', c, se_c, z_c, p_c);
if p_c < 0.05 && c > 0
    fprintf('Regret has a significantly LARGER magnitude effect than Relief at L1 (loss-aversion pattern).\n');
elseif p_c < 0.05 && c < 0
    fprintf('Relief has a significantly LARGER magnitude effect than Regret at L1 (opposite of loss-aversion).\n');
else
    fprintf('No significant asymmetry between Regret and Relief magnitude at L1.\n');
end
 
%% ---- (b) Per-subject paired test on |beta| ----
fprintf('\n======== (b) Per-subject paired test: |beta_Regret_L1| vs |beta_Relief_L1| ========\n');
subj_list = unique(T.Subject);
n_subs    = length(subj_list);
beta_reg_subj = nan(n_subs,1);
beta_rel_subj = nan(n_subs,1);
 
for i = 1:n_subs
    T_s = T(T.Subject == subj_list(i), :);
    if size(T_s,1) < 30, continue; end
    try
        mdl_s = fitglm(T_s, f_reg_rel_1(1:end-length(' + (1|Subject)')), ...
                       'Distribution','Binomial','Link','logit');
        idx1 = strcmp(mdl_s.CoefficientNames, 'Regret_chosen_L1');
        idx2 = strcmp(mdl_s.CoefficientNames, 'Relief_notchosen_L1');
        if any(idx1), beta_reg_subj(i) = mdl_s.Coefficients.Estimate(idx1); end
        if any(idx2), beta_rel_subj(i) = mdl_s.Coefficients.Estimate(idx2); end
    catch
        % leave as NaN
    end
end
 
valid_pair = ~isnan(beta_reg_subj) & ~isnan(beta_rel_subj);
abs_reg = abs(beta_reg_subj(valid_pair));
abs_rel = abs(beta_rel_subj(valid_pair));
 
[~, p_paired, ~, stats_paired] = ttest(abs_reg, abs_rel);
fprintf('N subjects with both estimates = %d\n', sum(valid_pair));
fprintf('Mean |beta_Regret_L1| = %.4f, Mean |beta_Relief_L1| = %.4f\n', mean(abs_reg), mean(abs_rel));
fprintf('Paired t-test: t(%d) = %.3f, p = %.5f\n', stats_paired.df, stats_paired.tstat, p_paired);
if p_paired < 0.05 && mean(abs_reg) > mean(abs_rel)
    fprintf('Confirms: Regret magnitude > Relief magnitude across subjects (loss-aversion).\n');
elseif p_paired < 0.05
    fprintf('Relief magnitude > Regret magnitude across subjects.\n');
else
    fprintf('No significant per-subject asymmetry.\n');
end
 
%% ---- plot: per-subject paired comparison ----
figure('Color','w','Position',[100 100 500 450]);
hold on;
for i = 1:length(abs_reg)
    plot([1 2], [abs_reg(i) abs_rel(i)], '-', 'Color',[0.7 0.7 0.7]);
end
plot(ones(size(abs_reg)), abs_reg, 'ro', 'MarkerFaceColor','r', 'MarkerSize',6);
plot(2*ones(size(abs_rel)), abs_rel, 'bo', 'MarkerFaceColor','b', 'MarkerSize',6);
plot([1 2], [mean(abs_reg) mean(abs_rel)], 'k-', 'LineWidth', 3);
set(gca,'XTick',[1 2],'XTickLabel',{'|Regret_{L1}|','|Relief_{L1}|'});
xlim([0.5 2.5]);
ylabel('|\beta|');
title({'Per-subject Regret vs Relief magnitude', ...
    sprintf('paired t(%d)=%.2f, p=%.4f', stats_paired.df, stats_paired.tstat, p_paired)});
grid on; box on; hold off;


%% ============================================================
%  Regret x Relief crossover across lags
%  Tests whether the asymmetry (Regret stronger at L1, Relief
%  stronger at L3-L6) is statistically real, not just visual.
% ============================================================

%% ---- (1) Per-lag Wald contrast: |b_Regret_Lk| vs |b_Relief_Lk| for EACH k ----
% (uses the model that has ONLY Regret_chosen_L1-6 + Relief_notchosen_L1-6,

f_regret_relief_only = ['Choice_top ~ ' regret_cho_terms ' + ' relief_nc_terms ' + (1|Subject)'];
mdl_rr = fitglme(T, f_regret_relief_only, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace','OptimizerOptions',opts);

fprintf('=== Per-lag magnitude contrast: |Regret_Lk| vs |Relief_Lk| ===\n');
fprintf('%-5s %-10s %-10s %-10s %-10s %-10s\n','Lag','b_Regret','b_Relief','diff','z','p');
CovB = mdl_rr.CoefficientCovariance;

for k = 1:6
    idx_r = strcmp(mdl_rr.CoefficientNames, ['Regret_chosen_L' num2str(k)]);
    idx_l = strcmp(mdl_rr.CoefficientNames, ['Relief_notchosen_L' num2str(k)]);

    b_r = mdl_rr.Coefficients.Estimate(idx_r);
    b_l = mdl_rr.Coefficients.Estimate(idx_l);
    var_r = CovB(idx_r, idx_r);
    var_l = CovB(idx_l, idx_l);
    cov_rl = CovB(idx_r, idx_l);

    s_r = sign(b_r); s_l = sign(b_l);
    c = abs(b_r) - abs(b_l);
    grad = [s_r; -s_l];
    Cov2 = [var_r cov_rl; cov_rl var_l];
    se_c = sqrt(grad' * Cov2 * grad);
    z_c = c / se_c;
    p_c = 2*(1 - normcdf(abs(z_c)));

    sig = '';
    if p_c < 0.001, sig='***'; elseif p_c<0.01, sig='**'; elseif p_c<0.05, sig='*'; end

    fprintf('L%-4d %-10.4f %-10.4f %-10.4f %-10.3f %-10.5f %s\n', k, b_r, b_l, c, z_c, p_c, sig);
end
fprintf('(positive diff = Regret stronger; negative diff = Relief stronger)\n');


%% ============================================================
%  REGRET vs RELIEF: formal decay-rate comparison
% ============================================================

k_vec = (1:6)'; %lags vector

%% ============================================================
%  (1) Point estimate: fit decay curves to the GROUP-LEVEL model
% ============================================================
fprintf('======== (1) Group-level decay curve fit ========\n');

regret_lag_names = strcat('Regret_chosen_', lags);
relief_lag_names = strcat('Relief_notchosen_', lags);

regret_terms_all = strjoin(regret_lag_names, ' + ');
relief_terms_all = strjoin(relief_lag_names, ' + ');
f_rr = ['Choice_top ~ ' regret_terms_all ' + ' relief_terms_all ' + (1|Subject)'];
mdl_rr = fitglme(T, f_rr, 'Distribution','Binomial','Link','logit', ...
    'FitMethod','Laplace','OptimizerOptions',opts);

b_regret = nan(6,1); b_relief = nan(6,1);
for k = 1:6
    idx = strcmp(mdl_rr.CoefficientNames, ['Regret_chosen_L' num2str(k)]);
    b_regret(k) = mdl_rr.Coefficients.Estimate(idx);
    idx = strcmp(mdl_rr.CoefficientNames, ['Relief_notchosen_L' num2str(k)]);
    b_relief(k) = mdl_rr.Coefficients.Estimate(idx);
end

% decay model: b_k = A * exp(-(k-1)/tau)
decay_fun = @(p,k) p(1) * exp(-(k-1)/p(2));  % p = [A, tau]

opts_fit = statset('Display','off','MaxIter',1000);
p0 = [-0.05, 2];  % starting guess: A negative , tau~2 lags

mdl_nl_regret = fitnlm(k_vec, b_regret, @(p,k) decay_fun(p,k), p0, 'Options', opts_fit);
mdl_nl_relief = fitnlm(k_vec, b_relief, @(p,k) decay_fun(p,k), p0, 'Options', opts_fit);

A_regret = mdl_nl_regret.Coefficients.Estimate(1); tau_regret = mdl_nl_regret.Coefficients.Estimate(2);
A_relief = mdl_nl_relief.Coefficients.Estimate(1); tau_relief = mdl_nl_relief.Coefficients.Estimate(2);

fprintf('Regret: A = %.4f, tau = %.2f lags (half-life = %.2f lags)\n', A_regret, tau_regret, tau_regret*log(2));
fprintf('Relief: A = %.4f, tau = %.2f lags (half-life = %.2f lags)\n', A_relief, tau_relief, tau_relief*log(2));
fprintf('Point-estimate difference: tau_relief - tau_regret = %.2f lags\n', tau_relief - tau_regret);
fprintf('(positive => Relief decays MORE SLOWLY / persists LONGER than Regret)\n');

%% ---- plot: observed points + fitted decay curves ----
k_fine = linspace(1,6,100);
figure('Color','w','Position',[100 100 700 450]);
hold on;
errorbar(k_vec, b_regret, mdl_rr.Coefficients.SE(ismember(mdl_rr.CoefficientNames, regret_lag_names)), ...
    'ro', 'MarkerFaceColor','r', 'MarkerSize',7, 'LineStyle','none');
errorbar(k_vec, b_relief, mdl_rr.Coefficients.SE(ismember(mdl_rr.CoefficientNames, relief_lag_names)), ...
    'bs', 'MarkerFaceColor','b', 'MarkerSize',7, 'LineStyle','none');
plot(k_fine, decay_fun([A_regret tau_regret], k_fine), 'r-', 'LineWidth',2);
plot(k_fine, decay_fun([A_relief tau_relief], k_fine), 'b-', 'LineWidth',2);
plot([0.5 6.5],[0 0],'k--');
xlabel('Lag'); ylabel('\beta (logit)');
xlim([0.5 6.5]);
legend({'Regret (observed)','Relief (observed)', ...
    sprintf('Regret fit (\\tau=%.2f)', tau_regret), ...
    sprintf('Relief fit (\\tau=%.2f)', tau_relief)}, 'Location','SouthEast');
title('Regret vs Relief: fitted exponential decay');
grid on; box on; hold off;

%% ============================================================
%  (2) Bootstrap CI on tau_relief - tau_regret (resample SUBJECTS,
%      not trials, to respect the clustered/non-independent structure)
% ============================================================
fprintf('\n======== (2) Bootstrap: resampling subjects ========\n');

subj_list = unique(T.Subject);
n_subs = length(subj_list);

% pre-extract per-subject lag coefficient VECTORS (fast fixed-effects
% GLM per subject - no grid search, no EWMA, just 12 well-behaved terms)
f_subj_all = ['Choice_top ~ ' regret_terms_all ' + ' relief_terms_all];
beta_reg_mat = nan(n_subs, 6);
beta_rel_mat = nan(n_subs, 6);

fprintf('Fitting per-subject lag coefficients (one pass, cached for bootstrap)...\n');
for i = 1:n_subs
    T_s = T(T.Subject == subj_list(i), :);
    if height(T_s) < 60, continue; end
    try
        mdl_s = fitglm(T_s, f_subj_all, 'Distribution','Binomial','Link','logit');
        for k = 1:6
            idx = strcmp(mdl_s.CoefficientNames, ['Regret_chosen_L' num2str(k)]);
            beta_reg_mat(i,k) = mdl_s.Coefficients.Estimate(idx);
            idx = strcmp(mdl_s.CoefficientNames, ['Relief_notchosen_L' num2str(k)]);
            beta_rel_mat(i,k) = mdl_s.Coefficients.Estimate(idx);
        end
    catch
    end
end

valid_subj = ~any(isnan(beta_reg_mat),2) & ~any(isnan(beta_rel_mat),2);
beta_reg_mat = beta_reg_mat(valid_subj,:); %beta coefficients for 6 lags. each row= subject
beta_rel_mat = beta_rel_mat(valid_subj,:);
n_valid = size(beta_reg_mat,1);
fprintf('%d of %d subjects had usable per-subject fits.\n', n_valid, n_subs);

rng(1);
n_boot = 2000;
tau_diff_boot = nan(n_boot,1);

fprintf('Running %d bootstrap resamples...\n', n_boot);
for b = 1:n_boot
    samp_idx = randi(n_valid, n_valid, 1);   % resample subjects with replacement
    mean_reg = mean(beta_reg_mat(samp_idx,:), 1)';
    mean_rel = mean(beta_rel_mat(samp_idx,:), 1)';

    try
        m_r = fitnlm(k_vec, mean_reg, @(p,k) decay_fun(p,k), p0, 'Options', opts_fit);
        m_l = fitnlm(k_vec, mean_rel, @(p,k) decay_fun(p,k), p0, 'Options', opts_fit);
        tau_r = m_r.Coefficients.Estimate(2);
        tau_l = m_l.Coefficients.Estimate(2);
        % guard against pathological fits (huge/negative tau from noisy bootstrap samples)
        if tau_r > 0 && tau_r < 50 && tau_l > 0 && tau_l < 50
            tau_diff_boot(b) = tau_l - tau_r;
        end
    catch
    end
end

valid_boot = ~isnan(tau_diff_boot);
tau_diff_boot = tau_diff_boot(valid_boot);
fprintf('%d of %d bootstrap fits succeeded and were valid.\n', sum(valid_boot), n_boot);

ci_lo = prctile(tau_diff_boot, 2.5); %confidence interval low
ci_hi = prctile(tau_diff_boot, 97.5); % high
p_boot = 2*min(mean(tau_diff_boot<=0), mean(tau_diff_boot>=0));

fprintf('\nBootstrap tau_relief - tau_regret: mean = %.2f, 95%% CI = [%.2f, %.2f]\n', ...
    mean(tau_diff_boot), ci_lo, ci_hi);
fprintf('Bootstrap p-value (two-sided, proportion crossing zero) = %.4f\n', p_boot);
if ci_lo > 0
    fprintf('CI excludes zero and is entirely positive: Relief decays significantly more slowly than Regret.\n');
elseif ci_hi < 0
    fprintf('CI excludes zero and is entirely negative: Regret decays significantly more slowly than Relief.\n');
else
    fprintf('CI includes zero: decay-rate difference is not statistically confirmed by this bootstrap.\n');
end

figure('Color','w','Position',[100 100 600 420]);

[n,x] = hist(tau_diff_boot,40);
bar(x,n);
hold on;

yl = ylim;

plot([0 0],yl,'k--','LineWidth',1.5);

mu = mean(tau_diff_boot);
plot([mu mu],yl,'r-','LineWidth',2);

xlabel('\tau_{relief} - \tau_{regret} (lags)');
ylabel('Bootstrap count');

title(sprintf('Bootstrap distribution (N=%d) | 95%% CI [%.2f, %.2f]', ...
    sum(valid_boot), ci_lo, ci_hi));

grid on;
box on;


