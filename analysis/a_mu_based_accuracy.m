%% === Mu based accuracy === 

%    circle   = Option1  (Mu_Option1) in runs csv files
%    square   = Option2  (Mu_Option2)
%    triangle = Option3  (Mu_Option3)

% put "runs_table_csv' files in the same folder as subjects data

dataPath = 'D:\my task\subjects\final_touch_acuuracy';  

matFiles = dir(fullfile(dataPath,'*_results.mat'));

subject_names = {};
subject_files = {};

for i = 1:length(matFiles)

    fname = matFiles(i).name;

    %remove this part
    baseName = regexprep(fname,'_results\.mat$','');

    %seperate name from the number
    tok = regexp(baseName,'^(.*?)(\d+)$','tokens');

    if isempty(tok)
        continue
    end

    subj = tok{1}{1};      %name
    run  = tok{1}{2};     %number

    idx = find(strcmp(subject_names,subj));

    if isempty(idx)
        subject_names{end+1} = subj;
        subject_files{end+1} = {baseName};
    else
        subject_files{idx}{end+1} = baseName;
    end
end

for i = 1:length(subject_files)

    runs = cellfun(@(x) ...
        str2double(regexp(x,'\d+$','match','once')), ...
        subject_files{i});

    [~,ord] = sort(runs);

    subject_files{i} = subject_files{i}(ord);
end

shape2opt = struct('circle',1,'square',2,'triangle',3);

%% ============================================================
 % main loop
% ============================================================
n_subjects  = length(subject_files);
acc_s1_all  = nan(n_subjects,1);   %session 1
acc_s2_all  = nan(n_subjects,1);   % session 2
acc_both_all = nan(n_subjects,1);  %both
full_subject_names = cell(n_subjects,1);

fprintf('%-25s %-12s %-12s %-12s\n','Subject','Acc_S1(%)','Acc_S2(%)','Acc_Both(%)');
fprintf('%s\n', repmat('-',1,62));

for si = 1:n_subjects

    correct_s1 = []; n_s1 = 0;
    correct_s2 = []; n_s2 = 0;

    for part = 1:2
        fname = subject_files{si}{part};   

        tokens   = regexp(fname, '(\d+)$', 'tokens');
        run_num  = str2double(tokens{1}{1});
        csv_name = sprintf('run_%04d_table.csv', run_num);
        csv_path = fullfile(dataPath, csv_name);

        % Load CSV
        if ~exist(csv_path,'file')
            fprintf('WARNING: %s not found\n', csv_path);
            continue;
        end
        csv_data = readtable(csv_path);
        mu = [csv_data.Mu_Option1, csv_data.Mu_Option2, csv_data.Mu_Option3];
        % mu: n_trials × 3 ? mu(t,1)=circle, mu(t,2)=square, mu(t,3)=triangle

        % load subject data 
        mat_path = fullfile(dataPath, [fname '_results.mat']);
        if ~exist(mat_path,'file')
            fprintf('WARNING: %s not found\n', mat_path);
            continue;
        end
        loaded  = load(mat_path);
        regretD = loaded.regretD;
        n       = length(regretD);

        correct_part = nan(n,1);

        for t = 1:n
            resp = regretD(t).resp_shape;

            %skip no responce trials
            if isempty(resp), continue; end

            
            top_sh = regretD(t).topShape;
            bot_sh = regretD(t).bottomShape;

            %option numbers for this trial
            top_opt = shape2opt.(top_sh);
            bot_opt = shape2opt.(bot_sh);
            cho_opt = shape2opt.(resp);


            mu_top = mu(t, top_opt);
            mu_bot = mu(t, bot_opt);
            mu_cho = mu(t, cho_opt);   %mu of chosen shape

            % skip if shapes have equal mu
            if mu_top == mu_bot, continue; end

            %was better shape chosen?
            mu_better = max(mu_top, mu_bot);
            correct_part(t) = double(mu_cho == mu_better);
        end

        
        valid = ~isnan(correct_part);
        if part == 1
            correct_s1 = correct_part(valid);
            n_s1       = sum(valid);
        else
            correct_s2 = correct_part(valid);
            n_s2       = sum(valid);
        end
    end

    %Accuracy calculation
    if n_s1 > 0
        acc_s1_all(si) = 100 * mean(correct_s1);
    end
    if n_s2 > 0
        acc_s2_all(si) = 100 * mean(correct_s2);
    end
    if n_s1 + n_s2 > 0
        acc_both_all(si) = 100 * mean([correct_s1; correct_s2]);
    end

    %prin t the results 
    subj_label = [subject_files{si}{1} ' / ' subject_files{si}{2}];
    full_subject_names{si} = ...
    [subject_files{si}{1} '/' subject_files{si}{2}];
    fprintf('%-25s %-12.1f %-12.1f %-12.1f\n', subj_label, ...
            acc_s1_all(si), acc_s2_all(si), acc_both_all(si));
end

%% ============================================================
% group results
% ============================================================
fprintf('%s\n', repmat('-',1,62));
fprintf('%-25s %-12.1f %-12.1f %-12.1f\n', 'GROUP MEAN', ...
        nanmean(acc_s1_all), nanmean(acc_s2_all), nanmean(acc_both_all));
fprintf('%-25s %-12.1f %-12.1f %-12.1f\n', 'GROUP SD', ...
        nanstd(acc_s1_all), nanstd(acc_s2_all), nanstd(acc_both_all));
fprintf('%-25s %-12d %-12d %-12d\n', 'N valid', ...
        sum(~isnan(acc_s1_all)), sum(~isnan(acc_s2_all)), sum(~isnan(acc_both_all)));

%% ============================================================
% Is accuracy higher than chance level(50%)?
% ============================================================
fprintf('\n--- Binomial test vs 50%% (using Both sessions) ---\n');
for si = 1:n_subjects
    if isnan(acc_both_all(si)), continue; end


    subj_label = [subject_files{si}{1} '/' subject_files{si}{2}];
    fprintf('  %-22s  %.1f%%\n', subj_label, acc_both_all(si));
end

%% binomial test 
[~, p_grp, ~, stats_grp] = ttest(acc_both_all(~isnan(acc_both_all)), 50, 'Tail','right');
fprintf('\nGroup t-test vs 50%%: mean=%.1f%%, t(%d)=%.3f, p=%.4f\n', ...
        nanmean(acc_both_all), stats_grp.df, stats_grp.tstat, p_grp);


%% ============================================================
% plot
% ============================================================
valid_idx = find(~isnan(acc_both_all));
n_valid   = length(valid_idx);

figure('Color','w','Position',[100 100 900 420]);

%% ============================================================
% plot : per-subject accuracy
% ============================================================

hold on;

x = 1:n_valid;

b1 = bar(x-0.2, acc_s1_all(valid_idx), 0.35);
set(b1,'FaceColor',[0.4 0.6 0.9]);

b2 = bar(x+0.2, acc_s2_all(valid_idx), 0.35);
set(b2,'FaceColor',[0.9 0.5 0.3]);

plot([0 n_valid+1],[50 50],'k--','LineWidth',1.5);

xlabels = cell(n_valid,1);

for i = 1:n_valid
    xlabels{i} = subject_files{valid_idx(i)}{1};
    xlabels{i} = regexprep(xlabels{i},'\d+$','');
end

set(gca,...
    'XTick',1:n_valid,...
    'XTickLabel',[],...
    'FontSize',7);

ylabel('Accuracy (%)','FontSize',11);
title('Per-subject accuracy','FontSize',11);

legend([b1 b2],{'Session 1','Session 2'},...
       'Location','SouthOutside');

ylim([30 100]);

grid on;
box on;

% ---------- rotated labels ----------
yl = ylim;

for i = 1:n_valid

    text(i,...
         yl(1)-2,...
         xlabels{i},...
         'Rotation',45,...
         'HorizontalAlignment','right',...
         'VerticalAlignment','top',...
         'FontSize',7);

end
   
saveas(gcf,'mu_based_accuracy.png');  
%% ============================================================
% Save results
% ============================================================

mu_accuracy.subject_names = subject_names;
mu_accuracy.subject_files = subject_files;
mu_accuracy.full_subject_names = full_subject_names;

mu_accuracy.acc_s1_all    = acc_s1_all;
mu_accuracy.acc_s2_all    = acc_s2_all;
mu_accuracy.acc_both_all  = acc_both_all;

mu_accuracy.group_mean_s1   = nanmean(acc_s1_all);
mu_accuracy.group_mean_s2   = nanmean(acc_s2_all);
mu_accuracy.group_mean_both = nanmean(acc_both_all);

mu_accuracy.group_sd_s1   = nanstd(acc_s1_all);
mu_accuracy.group_sd_s2   = nanstd(acc_s2_all);
mu_accuracy.group_sd_both = nanstd(acc_both_all);

mu_accuracy.n_valid_s1   = sum(~isnan(acc_s1_all));
mu_accuracy.n_valid_s2   = sum(~isnan(acc_s2_all));
mu_accuracy.n_valid_both = sum(~isnan(acc_both_all));

mu_accuracy.ttest_p  = p_grp;
mu_accuracy.ttest_t  = stats_grp.tstat;
mu_accuracy.ttest_df = stats_grp.df;

save(fullfile(dataPath,'accuracy_results.mat'),...
     'mu_accuracy');

fprintf('\nResults saved to:\n%s\n', ...
        fullfile(dataPath,'accuracy_results.mat'));