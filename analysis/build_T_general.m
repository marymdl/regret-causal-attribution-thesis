function T = build_T_general(alpha_ewma, basePath, subject_files, n_subjects, arms, n_lags, half_trial)
%  Random reward explanation: For each arm , 12 history queues track the magnitude of the random
%  reward under every combination of:
%    - Status  : chosen (cho) vs unchosen (unc) at trial t-1
%    - Timing  : same trial as choice (t0) vs feedback trial (t1)
%    - Position: same position as X (same), different (diff), any (any)
%
%  Each queue stores the magnitude of the random reward when the
%  condition was met, or 0 when it was not (including when no random
%  reward appeared at all).
%

    push_queue = @(q, val) [val, q(1:end-1)];   %q: the sequence list / val: new value

    safe_mag = @(m) replaceNaN(m);  %if rndm rwd is NaN, return zero.
    function x = replaceNaN(x)
        x(isnan(x)) = 0;
    end

    all_rows = [];

    for s = 1:n_subjects

        nan_q  = nan(1, n_lags); % make n lags

        %% ---- reset all histories for this subject ----
        cum_regret    = struct('circle', 0,   'square', 0,   'triangle', 0);

        for ai = 1:3  %loop into each shape
            a = arms{ai};

            %% standard histories
            hist_reward_chosen.(a)     = nan_q;
            hist_regret_chosen.(a)     = nan_q;
            hist_reward_notchosen.(a)  = nan_q;
            hist_relief_notchosen.(a)  = nan_q; %when the shape was not chosen and it caused relief

            %% 12 random-reward histories
            %%  naming: hist_rnd_<status>_<position>_<timing>
            %%  status:   cho = chosen arm,   unc = unchosen arm
            %%  position: same, diff, any
            %%  timing:   t0 = same trial as choice, t1 = feedback trial
    
            % --- chosen arm, same trial (t0) ---
            hist_rnd_cho_same_t0.(a) = nan_q;
            hist_rnd_cho_diff_t0.(a) = nan_q;
            hist_rnd_cho_any_t0.(a)  = nan_q;

            % --- chosen arm, feedback trial (t1) ---
            hist_rnd_cho_same_t1.(a) = nan_q;
            hist_rnd_cho_diff_t1.(a) = nan_q;
            hist_rnd_cho_any_t1.(a)  = nan_q;

            % --- unchosen arm, same trial (t0) ---
            hist_rnd_unc_same_t0.(a) = nan_q;
            hist_rnd_unc_diff_t0.(a) = nan_q;
            hist_rnd_unc_any_t0.(a)  = nan_q;

            % --- unchosen arm, feedback trial (t1) ---
            hist_rnd_unc_same_t1.(a) = nan_q;
            hist_rnd_unc_diff_t1.(a) = nan_q;
            hist_rnd_unc_any_t1.(a)  = nan_q;
        end

        for part = 1:2
            filename = fullfile(basePath, [subject_files{s}{part} '_results.mat']);
            loaded   = load(filename);
            regretD  = loaded.regretD;
            n        = length(regretD);

            %% extract raw variables
            mag_chosen     = nan(n,1);
            mag_notChosen  = nan(n,1);
            reward_random  = zeros(n,1);
            random_rwd_pos = cell(n,1);
            topShape       = cell(n,1);
            bottomShape    = cell(n,1);
            chosenShape    = cell(n,1);
            choice         = cell(n,1);
            RT_all         = nan(n,1);
            mag_random     = nan(n,1);

            for t = 1:n
                mag_chosen(t)    = regretD(t).mag_chosen;
                mag_notChosen(t) = regretD(t).mag_notChosen;
                reward_random(t) = regretD(t).reward_random;
                topShape{t}      = regretD(t).topShape;
                bottomShape{t}   = regretD(t).bottomShape;
                chosenShape{t}   = regretD(t).resp_shape;
                choice{t}        = regretD(t).choice;
                RT_all(t)        = regretD(t).RT;

                if isfield(regretD(t),'mag_random_rwd') && ~isnan(regretD(t).mag_random_rwd)
                    mag_random(t) = regretD(t).mag_random_rwd;
                end
                if isfield(regretD(t),'random_rwd_pos') && ~isempty(regretD(t).random_rwd_pos)
                    random_rwd_pos{t} = regretD(t).random_rwd_pos;
                else
                    random_rwd_pos{t} = '';
                end
            end

            %% trial loop
            for t = 2:n
                have_prev_choice = ~isempty(chosenShape{t-1});
                have_curr_choice = ~isempty(choice{t});

                armTop    = topShape{t};
                armBottom = bottomShape{t};

                %%  row-building only needs choice{t}
                RT_current   = RT_all(t);
                saw_feedback = ~isnan(RT_current) && RT_current > half_trial;

                build_row = @() [
                    s, t, part, ...
                    double(strcmp(choice{t}, 'top')), ...
                    hist_reward_chosen.(armTop)      - hist_reward_chosen.(armBottom), ...
                    hist_regret_chosen.(armTop)      - hist_regret_chosen.(armBottom), ...
                    hist_reward_notchosen.(armTop)   - hist_reward_notchosen.(armBottom), ...
                    hist_relief_notchosen.(armTop)   - hist_relief_notchosen.(armBottom), ...
                    hist_relief_chosen.(armTop)      - hist_relief_chosen.(armBottom), ...
                    hist_rnd_cho_same_t0.(armTop)    - hist_rnd_cho_same_t0.(armBottom), ...
                    hist_rnd_cho_diff_t0.(armTop)    - hist_rnd_cho_diff_t0.(armBottom), ...
                    hist_rnd_cho_any_t0.(armTop)     - hist_rnd_cho_any_t0.(armBottom), ...
                    hist_rnd_cho_same_t1.(armTop)    - hist_rnd_cho_same_t1.(armBottom), ...
                    hist_rnd_cho_diff_t1.(armTop)    - hist_rnd_cho_diff_t1.(armBottom), ...
                    hist_rnd_cho_any_t1.(armTop)     - hist_rnd_cho_any_t1.(armBottom), ...
                    hist_rnd_unc_same_t0.(armTop)    - hist_rnd_unc_same_t0.(armBottom), ...
                    hist_rnd_unc_diff_t0.(armTop)    - hist_rnd_unc_diff_t0.(armBottom), ...
                    hist_rnd_unc_any_t0.(armTop)     - hist_rnd_unc_any_t0.(armBottom), ...
                    hist_rnd_unc_same_t1.(armTop)    - hist_rnd_unc_same_t1.(armBottom), ...
                    hist_rnd_unc_diff_t1.(armTop)    - hist_rnd_unc_diff_t1.(armBottom), ...
                    hist_rnd_unc_any_t1.(armTop)     - hist_rnd_unc_any_t1.(armBottom), ...
                    cum_regret.(armTop) - cum_regret.(armBottom), ...
                    (cum_regret.circle + cum_regret.square + cum_regret.triangle) / 3, ...
                ];

                row = [];  % will stay empty if have_curr_choice is false - not added to all_rows
                if have_curr_choice && ~saw_feedback
                    row = build_row();
                end

                %%  History update only needs chosenShape{t-1} 
                %  (mag_chosen(t)/mag_notChosen(t)/reward_random(t) are feedback about
                %  trial t-1's choice, shown during trial t, independent of whether
                %  the person responded at trial t)
                if have_prev_choice && ~isnan(mag_chosen(t)) && ~isnan(mag_notChosen(t))
                    prevChosen = chosenShape{t-1};
                    if strcmp(prevChosen, topShape{t-1})
                        prevUnchosen    = bottomShape{t-1};
                        prevChosenPos   = 'top';
                        prevUnchosenPos = 'bottom';
                    else
                        prevUnchosen    = topShape{t-1};
                        prevChosenPos   = 'bottom';
                        prevUnchosenPos = 'top';
                    end

                    regret_val = max(0, mag_notChosen(t) - mag_chosen(t));
                    relief_val = max(0, mag_chosen(t)    - mag_notChosen(t));

                    %% --- random at trial t-1 (same trial as the choice) ---
                    rnd0_shown = logical(reward_random(t-1));
                    rnd0_mag   = safe_mag(mag_random(t-1));
                    rnd0_pos   = random_rwd_pos{t-1};

                    cho_same0  = rnd0_shown && ~isempty(rnd0_pos) && strcmp(rnd0_pos, prevChosenPos);
                    cho_diff0  = rnd0_shown && ~isempty(rnd0_pos) && ~strcmp(rnd0_pos, prevChosenPos);
                    unc_same0  = rnd0_shown && ~isempty(rnd0_pos) && strcmp(rnd0_pos, prevUnchosenPos);
                    unc_diff0  = rnd0_shown && ~isempty(rnd0_pos) && ~strcmp(rnd0_pos, prevUnchosenPos);

                    v_cho_same_t0 = double(cho_same0) * rnd0_mag;
                    v_cho_diff_t0 = double(cho_diff0) * rnd0_mag;
                    v_cho_any_t0  = double(rnd0_shown) * rnd0_mag;

                    v_unc_same_t0 = double(unc_same0) * rnd0_mag;
                    v_unc_diff_t0 = double(unc_diff0) * rnd0_mag;
                    v_unc_any_t0  = double(rnd0_shown) * rnd0_mag;

                    %% --- random at trial t (feedback trial) ---
                    rnd1_shown = logical(reward_random(t));
                    rnd1_mag   = safe_mag(mag_random(t));
                    rnd1_pos   = random_rwd_pos{t};

                    cho_same1  = rnd1_shown && ~isempty(rnd1_pos) && strcmp(rnd1_pos, prevChosenPos);
                    cho_diff1  = rnd1_shown && ~isempty(rnd1_pos) && ~strcmp(rnd1_pos, prevChosenPos);
                    unc_same1  = rnd1_shown && ~isempty(rnd1_pos) && strcmp(rnd1_pos, prevUnchosenPos);
                    unc_diff1  = rnd1_shown && ~isempty(rnd1_pos) && ~strcmp(rnd1_pos, prevUnchosenPos);

                    v_cho_same_t1 = double(cho_same1) * rnd1_mag;
                    v_cho_diff_t1 = double(cho_diff1) * rnd1_mag;
                    v_cho_any_t1  = double(rnd1_shown) * rnd1_mag;

                    v_unc_same_t1 = double(unc_same1) * rnd1_mag;
                    v_unc_diff_t1 = double(unc_diff1) * rnd1_mag;
                    v_unc_any_t1  = double(rnd1_shown) * rnd1_mag;

                    hist_reward_chosen.(prevChosen)     = push_queue(hist_reward_chosen.(prevChosen),    mag_chosen(t));
                    hist_regret_chosen.(prevChosen)     = push_queue(hist_regret_chosen.(prevChosen),    regret_val);
                    hist_reward_notchosen.(prevUnchosen)= push_queue(hist_reward_notchosen.(prevUnchosen), mag_notChosen(t));
                    hist_relief_notchosen.(prevUnchosen)= push_queue(hist_relief_notchosen.(prevUnchosen), relief_val);
                    hist_relief_chosen.(prevchosen)= push_queue(hist_relief_chosen.(prevchosen), relief_val);
                    hist_rnd_cho_same_t0.(prevChosen) = push_queue(hist_rnd_cho_same_t0.(prevChosen), v_cho_same_t0);
                    hist_rnd_cho_diff_t0.(prevChosen) = push_queue(hist_rnd_cho_diff_t0.(prevChosen), v_cho_diff_t0);
                    hist_rnd_cho_any_t0.(prevChosen)  = push_queue(hist_rnd_cho_any_t0.(prevChosen),  v_cho_any_t0);

                    hist_rnd_cho_same_t1.(prevChosen) = push_queue(hist_rnd_cho_same_t1.(prevChosen), v_cho_same_t1);
                    hist_rnd_cho_diff_t1.(prevChosen) = push_queue(hist_rnd_cho_diff_t1.(prevChosen), v_cho_diff_t1);
                    hist_rnd_cho_any_t1.(prevChosen)  = push_queue(hist_rnd_cho_any_t1.(prevChosen),  v_cho_any_t1);

                    hist_rnd_unc_same_t0.(prevUnchosen) = push_queue(hist_rnd_unc_same_t0.(prevUnchosen), v_unc_same_t0);
                    hist_rnd_unc_diff_t0.(prevUnchosen) = push_queue(hist_rnd_unc_diff_t0.(prevUnchosen), v_unc_diff_t0);
                    hist_rnd_unc_any_t0.(prevUnchosen)  = push_queue(hist_rnd_unc_any_t0.(prevUnchosen),  v_unc_any_t0);

                    hist_rnd_unc_same_t1.(prevUnchosen) = push_queue(hist_rnd_unc_same_t1.(prevUnchosen), v_unc_same_t1);
                    hist_rnd_unc_diff_t1.(prevUnchosen) = push_queue(hist_rnd_unc_diff_t1.(prevUnchosen), v_unc_diff_t1);
                    hist_rnd_unc_any_t1.(prevUnchosen)  = push_queue(hist_rnd_unc_any_t1.(prevUnchosen),  v_unc_any_t1);

                    cum_regret.(prevChosen) = alpha_ewma * regret_val + (1 - alpha_ewma) * cum_regret.(prevChosen);
                end

                if have_curr_choice && saw_feedback
                    row = build_row();
                end

                if have_curr_choice
                    all_rows = [all_rows; row];
                end
            end
        end
   end

    %% ============================================================
    %  Build variable names
    % ============================================================
    lags = {'L1','L2','L3','L4','L5','L6'};

    var_names = {'Subject','Trial','Session','Choice_top'};

    for L = lags, var_names{end+1} = ['Reward_chosen_'    L{1}]; end
    for L = lags, var_names{end+1} = ['Regret_chosen_'    L{1}]; end
    for L = lags, var_names{end+1} = ['Reward_notchosen_' L{1}]; end
    for L = lags, var_names{end+1} = ['Relief_notchosen_' L{1}]; end
    for L = lags, var_names{end+1} = ['Relief_chosen_' L{1}]; end

    rnd_blocks = {
        'Rnd_cho_same_t0', 'Rnd_cho_diff_t0', 'Rnd_cho_any_t0', ...
        'Rnd_cho_same_t1', 'Rnd_cho_diff_t1', 'Rnd_cho_any_t1', ...
        'Rnd_unc_same_t0', 'Rnd_unc_diff_t0', 'Rnd_unc_any_t0', ...
        'Rnd_unc_same_t1', 'Rnd_unc_diff_t1', 'Rnd_unc_any_t1' ...
    };
    for b = rnd_blocks
        for L = lags
            var_names{end+1} = [b{1} '_' L{1}];
        end
    end

    var_names{end+1} = 'CumRegret_diff';
    var_names{end+1} = 'CumRegret_mean_all';   % new column

    T = array2table(all_rows, 'VariableNames', var_names);
    T.Subject = categorical(T.Subject);

    predictor_cols = var_names(5:end-1);   % skip Subject, Trial, Session, Choice_top
    T = T(~any(isnan(T{:, predictor_cols}), 2), :);
end