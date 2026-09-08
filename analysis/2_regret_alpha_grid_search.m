%% ============================================================
%  Grid search for optimal alpha for CumRegret - CACHED VERSION
%  Fixes: build_alpha_search_data is called ONCE (not once per alpha),
%  and the per-alpha CumRegret_diff is recomputed cheaply by replaying
%  the cached raw_seq instead of re-reading files. Results are saved
%  to disk so re-opening MATLAB does not require rerunning the search.
% ============================================================

basePath      = 'D:\my task\subjects\all\run_based';
resultsFile   = fullfile(basePath, 'alpha_gridsearch_results.mat');
alpha_grid    = 0.05 : 0.05 : 1;
n_alpha       = length(alpha_grid);
half_trial    = 2;   % moveDuration/2, matches your earlier scripts
arms          = {'circle','square','triangle'};

if exist(resultsFile, 'file')
    fprintf('Cached results found - loading instead of rerunning the search.\n');
    load(resultsFile, 'll_s1','ll_s2','ll_both','best_alpha_s1','best_alpha_s2', ...
        'best_alpha_both','subj_names_gs','alpha_grid','subject_files','n_subjects');
else
    fprintf('No cache found - running the full grid search (this happens only once).\n');

    %% ---- build subject list (same pairing logic as before) ----
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

    subj_names_gs = cell(n_subjects,1);
    for si = 1:n_subjects
        subj_names_gs{si} = [subject_files{si}{1} '/' subject_files{si}{2}];
    end

    %% ---- build the data ONCE: T_base (alpha-independent) + raw_seq ----
    fprintf('Reading raw files once and caching sequences...\n');
    [T_base, raw_seq] = build_alpha_search_data(basePath, subject_files, n_subjects, arms, half_trial);
    T_base.Subject = categorical(T_base.Subject);

    f_regret = 'Choice_top ~ CumRegret_diff';

    ll_s1   = nan(n_subjects, n_alpha);
    ll_s2   = nan(n_subjects, n_alpha);
    ll_both = nan(n_subjects, n_alpha);

    fprintf('======== Grid search: optimal alpha ========\n');
    fprintf('%-4s %-8s\n','No.','Alpha');
    fprintf('%s\n', repmat('-',1,20));

    for a = 1:n_alpha
        al = alpha_grid(a);
        fprintf('%-4d %-8.2f\n', a, al);

        for si = 1:n_subjects
            seq_si = raw_seq{si};
            if isempty(seq_si), continue; end

            % cheaply recompute CumRegret_diff for this alpha by replaying
            % the cached sequence - no file I/O, no history rebuilding
            cum = zeros(3,1);
            cum_col = nan(size(seq_si,1),1);
            for r = 1:size(seq_si,1)
                prev_arm = seq_si(r,2);
                rval     = seq_si(r,3);
                arm_t    = seq_si(r,4);
                arm_b    = seq_si(r,5);
                cum_col(r) = cum(arm_t) - cum(arm_b);
                cum(prev_arm) = al * rval + (1 - al) * cum(prev_arm);
            end

            T_subj = T_base(T_base.Subject == categorical(si), :);
            T_subj.CumRegret_diff = cum_col;   % overwrite with this alpha's values

            %% ---- Session 1 ----
            T_s1 = T_subj(T_subj.Session == 1, :);
            if size(T_s1,1) >= 20
                try
                    mdl = fitglm(T_s1, f_regret, 'Distribution','Binomial','Link','logit');
                    ll_s1(si, a) = mdl.LogLikelihood;
                catch
                    ll_s1(si, a) = NaN;
                end
            end

            %% ---- Session 2 ----
            T_s2 = T_subj(T_subj.Session == 2, :);
            if size(T_s2,1) >= 20
                try
                    mdl = fitglm(T_s2, f_regret, 'Distribution','Binomial','Link','logit');
                    ll_s2(si, a) = mdl.LogLikelihood;
                catch
                    ll_s2(si, a) = NaN;
                end
            end

            %% ---- Both sessions ----
            if size(T_subj,1) >= 30
                try
                    mdl = fitglm(T_subj, f_regret, 'Distribution','Binomial','Link','logit');
                    ll_both(si, a) = mdl.LogLikelihood;
                catch
                    ll_both(si, a) = NaN;
                end
            end
        end
    end

    %% ---- find best alpha per subject per mode ----
    best_alpha_s1   = nan(n_subjects,1);
    best_alpha_s2   = nan(n_subjects,1);
    best_alpha_both = nan(n_subjects,1);
    for si = 1:n_subjects
        [~, idx] = max(ll_s1(si,:));   if ~isnan(ll_s1(si,idx)),   best_alpha_s1(si)   = alpha_grid(idx); end
        [~, idx] = max(ll_s2(si,:));   if ~isnan(ll_s2(si,idx)),   best_alpha_s2(si)   = alpha_grid(idx); end
        [~, idx] = max(ll_both(si,:)); if ~isnan(ll_both(si,idx)), best_alpha_both(si) = alpha_grid(idx); end
    end

    %% ---- save cache so this never has to run again ----
    save(resultsFile, 'll_s1','ll_s2','ll_both','best_alpha_s1','best_alpha_s2', ...
        'best_alpha_both','subj_names_gs','alpha_grid','subject_files','n_subjects');
    fprintf('Results saved to %s\n', resultsFile);
end

%% ============================================================
%  Summary table
% ============================================================
fprintf('\n%-22s %-12s %-12s %-12s\n','Subject','Alpha_S1','Alpha_S2','Alpha_Both');
fprintf('%s\n', repmat('-',1,60));
for si = 1:n_subjects
    fprintf('%-22s %-12.2f %-12.2f %-12.2f\n', ...
            subj_names_gs{si}, best_alpha_s1(si), best_alpha_s2(si), best_alpha_both(si));
end

fprintf('\n--- Group ---\n');
fprintf('%-10s %-10s %-10s\n','S1','S2','Both');
fprintf('Mean:   %-10.2f %-10.2f %-10.2f\n', ...
        nanmean(best_alpha_s1), nanmean(best_alpha_s2), nanmean(best_alpha_both));
fprintf('Median: %-10.2f %-10.2f %-10.2f\n', ...
        nanmedian(best_alpha_s1), nanmedian(best_alpha_s2), nanmedian(best_alpha_both));