function raw = load_subject_raw(basePath, part1_name, part2_name)
%   Loads and extracts the raw per-trial arrays for both
%   sessions of one subject. The returned struct has two fields,
%   part1 and part2, each containing the arrays needed by ql_negloglik.m:
%   n, mag_chosen, mag_notChosen, topShape, bottomShape, chosenShape,
%   choice, RT_all.

    raw = struct();
    part_names = {part1_name, part2_name};

    for part = 1:2
        filename = fullfile(basePath, [part_names{part} '_results.mat']);
        loaded  = load(filename);
        regretD = loaded.regretD;
        n = length(regretD);

        mag_chosen     = nan(n,1);
        mag_notChosen  = nan(n,1);
        topShape       = cell(n,1);
        bottomShape    = cell(n,1);
        chosenShape    = cell(n,1);
        choice         = cell(n,1);
        RT_all         = nan(n,1);

        for t = 1:n
            mag_chosen(t)    = regretD(t).mag_chosen;
            mag_notChosen(t) = regretD(t).mag_notChosen;
            topShape{t}      = regretD(t).topShape;
            bottomShape{t}   = regretD(t).bottomShape;
            chosenShape{t}   = regretD(t).resp_shape;
            choice{t}        = regretD(t).choice;
            RT_all(t)        = regretD(t).RT;
        end

        raw.(sprintf('part%d', part)) = struct( ...
            'n', n, ...
            'mag_chosen', mag_chosen, ...
            'mag_notChosen', mag_notChosen, ...
            'topShape', {topShape}, ...
            'bottomShape', {bottomShape}, ...
            'chosenShape', {chosenShape}, ...
            'choice', {choice}, ...
            'RT_all', RT_all);
    end
end
