function [T_base, raw_seq] = build_alpha_search_data_new(basePath, subject_files, n_subjects, arms, half_trial)
% BUILD_ALPHA_SEARCH_DATA  Reads each subject's raw files ONCE and
%   returns:
%     T_base  - table with Subject, Session, Choice_top, and the 6
%               alpha-INDEPENDENT control predictors (Reward_chosen_L1-3,
%               Reward_notchosen_L1-3). Much lighter than the full
%               build_T_general_rnd (no 6-lag regret/relief, no 72
%               random-reward columns - not needed for this search).
%     raw_seq - cell array, one entry per subject: an Nx5 matrix with
%               columns [Session, prevChosen_idx, regret_val,
%               armTop_idx, armBottom_idx], row-aligned exactly with
%               T_base(T_base.Subject==s,:). Replaying this sequence
%               with any alpha value reconstructs CumRegret_diff for
%               that subject WITHOUT re-reading any files or rebuilding
%               the reward-history queues.

    n_lags = 3;
    push_queue = @(q,val) [val q(1:end-1)];
    arm_idx = struct('circle',1,'square',2,'triangle',3);

    all_rows = [];
    raw_all  = [];   % [Session, prevChosen_idx, regret_val, armTop_idx, armBottom_idx]

    for s = 1:n_subjects
        nan_q = nan(1, n_lags);
        for ai = 1:3
            a = arms{ai};
            hist_reward_chosen.(a)    = nan_q;
            hist_reward_notchosen.(a) = nan_q;
        end

        for part = 1:2
            filename = fullfile(basePath, [subject_files{s}{part} '_results.mat']);
            loaded  = load(filename);
            regretD = loaded.regretD;
            n = length(regretD);

            mag_chosen    = nan(n,1);
            mag_notChosen = nan(n,1);
            topShape      = cell(n,1);
            bottomShape   = cell(n,1);
            chosenShape   = cell(n,1);
            choice        = cell(n,1);
            RT_all        = nan(n,1);

            for t = 1:n
                mag_chosen(t)    = regretD(t).mag_chosen;
                mag_notChosen(t) = regretD(t).mag_notChosen;
                topShape{t}      = regretD(t).topShape;
                bottomShape{t}   = regretD(t).bottomShape;
                chosenShape{t}   = regretD(t).resp_shape;
                choice{t}        = regretD(t).choice;
                RT_all(t)        = regretD(t).RT;
            end

            for t = 2:n
                if isempty(chosenShape{t-1}) || isempty(choice{t}), continue; end

                armTop    = topShape{t};
                armBottom = bottomShape{t};
                prevChosen = chosenShape{t-1};
                if strcmp(prevChosen, topShape{t-1})
                    prevUnchosen = bottomShape{t-1};
                else
                    prevUnchosen = topShape{t-1};
                end

                regret_val = max(0, mag_notChosen(t) - mag_chosen(t));

                RT_current   = RT_all(t);
                saw_feedback = ~isnan(RT_current) && RT_current > half_trial;

                build_row = @() [s, part, double(strcmp(choice{t},'top')), ...
                    hist_reward_chosen.(armTop)    - hist_reward_chosen.(armBottom), ...
                    hist_reward_notchosen.(armTop) - hist_reward_notchosen.(armBottom)];

                if ~saw_feedback
                    row = build_row();
                end

                hist_reward_chosen.(prevChosen)      = push_queue(hist_reward_chosen.(prevChosen),    mag_chosen(t));
                hist_reward_notchosen.(prevUnchosen)  = push_queue(hist_reward_notchosen.(prevUnchosen), mag_notChosen(t));

                if saw_feedback
                    row = build_row();
                end

                all_rows = [all_rows; row];
                raw_all  = [raw_all; part, arm_idx.(prevChosen), regret_val, arm_idx.(armTop), arm_idx.(armBottom)];
            end
        end
    end

    var_names = {'Subject','Session','Choice_top', ...
        'Reward_chosen_L1','Reward_chosen_L2','Reward_chosen_L3', ...
        'Reward_notchosen_L1','Reward_notchosen_L2','Reward_notchosen_L3'};

    T_base = array2table(all_rows, 'VariableNames', var_names);
    T_base.Subject = categorical(T_base.Subject);

    predictor_cols = var_names(4:end);
    valid_mask = ~any(isnan(T_base{:,predictor_cols}), 2);
    T_base = T_base(valid_mask, :);
    raw_all = raw_all(valid_mask, :);

    raw_seq = cell(n_subjects,1);
    subj_col = double(T_base.Subject);
    for s = 1:n_subjects
        raw_seq{s} = raw_all(subj_col == s, :);
    end

    % add a default CumRegret_diff column (alpha=0.5) so T_base is
    % structurally complete on its own; the alpha grid-search script
    % overwrites this column with the value computed for each tested
    % alpha, using the cached raw_seq (no re-reading files needed).
    default_alpha = 0.5;
    cum_col = nan(height(T_base), 1);
    for s = 1:n_subjects
        rows_s = find(subj_col == s);
        seq_s  = raw_seq{s};
        cum = zeros(3,1);
        for r = 1:size(seq_s,1)
            prev_arm = seq_s(r,2);
            rval     = seq_s(r,3);
            arm_t    = seq_s(r,4);
            arm_b    = seq_s(r,5);
            cum_col(rows_s(r)) = cum(arm_t) - cum(arm_b);
            cum(prev_arm) = default_alpha * rval + (1 - default_alpha) * cum(prev_arm);
        end
    end
    T_base.CumRegret_diff = cum_col;
end