%clear; clc
participantName = input('Participant:', 's');

Screen('Preference', 'SkipSyncTests', 1);
[w, rect] = Screen('OpenWindow', max(Screen('Screens')), [128 128 128], [0 0 1360 700] ); 
[centerX, centerY] = RectCenter(rect);


fps = Screen('NominalFrameRate', w);
if fps == 0; fps = 60;
end
ifi = 1/fps;
leftRect = [centerX-600, centerY-200, centerX-500, centerY+200];
rightRect = [centerX+500, centerY-200, centerX+600, centerY+200];

regretD = struct('trial', {}, 'topShape', {}, 'past_top_shape', {},'bottomShape', {}, 'past_bottom_shape', {},'resp_shape',{}, 'choice', {},'chosen_rwd_pos', {},'nonchosen_rwd_pos',{},'random_rwd_pos',{}, 'RT', {});

shapes = {'square','circle','triangle'};
nShapes = 3;

pairs = {
    'circle',  'square';
    'circle',  'triangle';
   'square',  'triangle';
     'square',  'circle';
    'triangle','circle';
    'triangle','square';};
nPairs = size(pairs,1);
nReps = 80; % nReps * 6 = trial numbers 
nTrials = nPairs * nReps;

pairs = repmat(pairs, nReps, 1);
%pairs = pairs(randperm(nTrials), :);

file_name = fullfile('D:\my task\Selected_RWs\std1\max3-min0.3', 'run_0088_table.csv');
data = readtable(file_name);
rwd_magnitude = struct();



moveDuration = 4 ;%s
speed = (rightRect(1) - leftRect(3)) / (moveDuration / ifi);
%rwd_t = 3; %after what duration can you show reward? favasel bayad mazrabe moveDuration bashan.
rwd_after_t = 1; 
reward_dur = 0.5*moveDuration; %How long reward is shown?  
reward_sh = 0;  %reward apear time variable. at each trial reward_sh shows the time of rwd apearance in the next trial

%% task loop

while 1 
      DrawFormattedText(w, 'press SPACE when you are ready', 'center' , 'center', [255 255 255]);
      Screen('TextSize', w, 40);
      Screen('Flip', w);
      [keyIsDown, ~, keyCode] = KbCheck;
      if keyIsDown && keyCode(KbName('space'))
           break;
       end
end
for t = 1:nTrials
    topShape = pairs{t,1};
    bottomShape = pairs{t,2};
    % % --- Initialization of data -- %%
    
     
    xPos = leftRect(3); %start point of the rectangles 
    yTop = centerY - 100;
    yBottom = centerY + 100;
    
    
    show_randomRwd = (rand < 0.50);

    reward_Chosen = false;
    reward_nonChosen = false;
    mag_Chosen = NaN;
    mag_nonChosen = NaN;
    mag_randomRWD = NaN;
    if t > rwd_after_t && ~isempty(regretD(t-rwd_after_t).choice)
        rwd_magnitude.circle   = data.Reward_Option1(t-rwd_after_t); %inaro Avordim inja ta magnitude reward t-1 dar trial t show besheh
        rwd_magnitude.square   = data.Reward_Option2(t-rwd_after_t);
        rwd_magnitude.triangle = data.Reward_Option3(t-rwd_after_t);
        pastChoice     = regretD(t-rwd_after_t).choice;
        pastTopShape    = regretD(t-rwd_after_t).topShape;
        pastBottomShape = regretD(t-rwd_after_t).bottomShape;
        
        if strcmp(pastChoice,'top')
            chosenShape   = pastTopShape;
            unchosenShape = pastBottomShape;
            regretD(t).chosen_rwd_pos    = 'top';     
            regretD(t).nonchosen_rwd_pos = 'bottom';
        elseif strcmp(pastChoice,'bottom')
            chosenShape   = pastBottomShape;
            unchosenShape = pastTopShape;
            regretD(t).chosen_rwd_pos    = 'bottom';     
            regretD(t).nonchosen_rwd_pos = 'top';
        else
            chosenShape   = '';
            unchosenShape = '';
            regretD(t).chosen_rwd_pos    = '';
            regretD(t).nonchosen_rwd_pos = '';
         end
        
        % ---- chosen reward magnitude ----
        if ~isempty(chosenShape)
               reward_Chosen = true;
               mag_Chosen = round(rwd_magnitude.(chosenShape));
        end
        
        % ---- unchosen reward magnitude  ----
        if ~isempty(unchosenShape)
                reward_nonChosen = true;
                mag_nonChosen = round(rwd_magnitude.(unchosenShape));
        end
    end
    
    % ---- randome reward magnitude ----
    if show_randomRwd
        mag_randomRWD = randi([1 99]);
    end
    
    % record for output
    regretD(t).reward_isgiven  = reward_Chosen;
    regretD(t).reward_random = show_randomRwd;
    regretD(t).mag_chosen  = mag_Chosen;
    regretD(t).mag_notChosen = mag_nonChosen;
    regretD(t).mag_random_rwd = mag_randomRWD; 
    if t > 1
        regretD(t).past_top_shape    = regretD(t-1).topShape;
        regretD(t).past_bottom_shape = regretD(t-1).bottomShape;
    else
        regretD(t).past_top_shape    = '';   
        regretD(t).past_bottom_shape = '';
    end
    
    % ---- response ----
    resp = '';
    resp_shape= '';
    RT = NaN;
    rewardShown = false;
    rewardAppearTime = 0;
    

    random_rwdPosition = []; 
    rightCenterX = mean([rightRect(1), rightRect(3)]);
    rightCenterY = mean([rightRect(2), rightRect(4)]);
    if show_randomRwd
        r = rand;
        if r < 0.5
            random_rwdPosition = [rightCenterX , rightCenterY-150];
            regretD(t).random_rwd_pos  = 'top';
        else
            random_rwdPosition = [rightCenterX  , rightCenterY+150];
            regretD(t).random_rwd_pos  = 'bottom';
        
        end
    end
     if reward_Chosen && ~isempty(regretD(t-rwd_after_t).choice)
        if strcmp(pastChoice, 'top')
           yReward_r = [rightCenterX, rightCenterY-150];
        else
           yReward_r = [rightCenterX, rightCenterY+150];
        end
     end  
     if reward_nonChosen && ~isempty(regretD(t-rwd_after_t).choice)
            if strcmp(pastChoice, 'top')
                yReward_g = [rightCenterX, rightCenterY+150];  
            else
                yReward_g = [rightCenterX, rightCenterY-150];    
            end
     end   

 %%
   startTime = GetSecs; 
   while GetSecs - startTime < moveDuration
 
        Screen('FillRect', w, [128 128 128]);
        
        Screen('FillRect', w, [80 80 80], leftRect);
        Screen('FillRect', w, [80 80 80], rightRect);
        
        drawShape(w, topShape, [xPos yTop], 50, [128 128 128]); %shapes' colors 
        drawShape(w, bottomShape, [xPos yBottom], 50, [128 128 128]);
        
        xPos = xPos + speed; %pos update
        
        [keyIsDown, secs, keyCode] = KbCheck;
        KbName('UnifyKeyNames');
        if keyIsDown && isempty(resp)
            if keyCode(KbName('UpArrow'))
                resp = 'top';
                resp_shape = topShape;
                not_chosen_shape = bottomShape;
                RT = secs - startTime;
            %    choice_t = GetSecs;
                reward_sh = (startTime*moveDuration) + (moveDuration*0.5);
            elseif keyCode(KbName('DownArrow'))
                resp = 'bottom';
                resp_shape = bottomShape;
                not_chosen_shape = topShape;
                RT = secs - startTime; 
             %   choice_t = GetSecs;
                reward_sh = (startTime*moveDuration) + (moveDuration*0.5);
            end
        end
        regretD(t).trial = t; 
        regretD(t).topShape = topShape;
        regretD(t).bottomShape = bottomShape;
        regretD(t).choice = resp;
        regretD(t).resp_shape = resp_shape; 
        regretD(t).RT = RT;
        regretD(t).reward_sh = reward_sh;
        
         trialEndTime = startTime + moveDuration;
         if t > rwd_after_t && trialEndTime-reward_dur < regretD(t-rwd_after_t).reward_sh
                 regretD(t-rwd_after_t).reward_sh = trialEndTime-reward_dur;
         end
        
         if t > rwd_after_t && (GetSecs - regretD(t-rwd_after_t).reward_sh) >= rewardAppearTime %&& (GetSecs - regretD(t-rwd_after_t).reward_sh)<= reward_dur
            rewardShown = true;
         end
         if t > rwd_after_t && (GetSecs - regretD(t-rwd_after_t).reward_sh) > reward_dur
            rewardShown = false;
         end
         if  (GetSecs - startTime) >= rewardAppearTime % && (GetSecs - startTime)<= reward_dur
            random_rewardShown = true;
         end
         if (GetSecs - startTime)> reward_dur
            random_rewardShown = false;
         end
         
         % --- Random reward ---
         if random_rewardShown
            if show_randomRwd && ~isempty(random_rwdPosition)
                drawRewardIcon(w, 'red', random_rwdPosition, mag_randomRWD);
            end
         end

        
        % --------------------------
        % DRAW REWARDS 
        % --------------------------
        if rewardShown  
            % --- Chosen reward ---
            if reward_Chosen
            drawRewardIcon(w, 'blue', yReward_r, mag_Chosen);
            end 
            
            % --- Grey reward ---
            if reward_nonChosen
                drawRewardIcon(w, 'grey', yReward_g, mag_nonChosen);
            end
        end 
%         if Draw_penalty
%             Screen('TextSize', w, 40);
%             Screen('TextStyle', w, 1);
%             DrawFormattedText(w,'-30' , centerX-100, centerY+250, [200, 0, 0]);
%         end

%        % draw progress bar 
%         barX      = 220;
%         barY      = rect(4) - 110;
%         barWidth  = rect(3) - 440;   
%         barHeight = 20;
%         barRect = [barX, barY, barX + barWidth, barY + barHeight];
%         Screen('FillRect', w, [20 25 25 35], barRect);
%         Screen('FrameRect', w, [100 200 255], barRect, 6);
%         % filled part of progress bar:
%          filledW = (progressTotal / finalr) * barWidth;
%         if filledW > 0
%             fillRect = [barX, barY, barX + filledW, barY + barHeight];
%             Screen('FillRect', w, [0 180 255], fillRect);  %fill with blue
%         end   
%         %Draw pointer
%         ptrX = barX + filledW;
%         Screen('DrawLine', w, [255 255 255], ptrX, barY - 30, ptrX, barY + barHeight + 30, 8);
%         %Write the number: x/1000
%         Screen('TextSize', w, 40);
%         Screen('TextStyle', w, 1);
%         DrawFormattedText(w, [num2str(round(progressTotal)) '/ 200'], 'center', barY - 65, [255 255 255]);
        
        Screen('Flip', w);
   end 
%             
%    if ~isnan(magRed)
%             switch resp_shape
%                 case 'circle',   realized_circle(t)   = magRed;
%                 case 'square',   realized_square(t)   = magRed;
%                 case 'triangle', realized_triangle(t) = magRed;
%             end
%    end
%     if ~isnan(magPink)
%             switch not_chosen_shape
%                 case 'circle',   realized_circle(t)   = magPink;
%                 case 'square',   realized_square(t)   = magPink;
%                 case 'triangle', realized_triangle(t) = magPink;
%             end
%     end
    
end

sca;
 filename = [participantName, '_results.mat'];
 figurename = [participantName, '_f_results.mat'];
 save(filename, 'regretD');

%%
% rankCount = zeros(1,3);
% for t = 1:nTrials
%     if isempty(regretD(t).resp_shape)
%         continue;
%     end
%     mu_t = [data.Reward_Option1(t), data.Reward_Option2(t), data.Reward_Option3(t)];
%     [~, rankIdx] = sort(mu_t, 'ascend');  
%     chosenIdx = find(strcmp(shapes, regretD(t).resp_shape));
%     chosenRank = find(rankIdx == chosenIdx);
%     bestRank = max(rankIdx);
%     rankCount(chosenRank) = rankCount(chosenRank) + 1;
% end
% rankPercent = 100 * rankCount / sum(rankCount);
% fprintf('Best chosen:    %.2f%%\n', rankPercent(1));
% fprintf('Second chosen:  %.2f%%\n', rankPercent(2));
% fprintf('Worst chosen:   %.2f%%\n', rankPercent(3));

%%

% Cumulative Regret
% cum_regret = 0;
% for t = 1:nTrials
%     if ~isempty(regretD(t).choice)
%         top_mu = muHistory(t). (regretD(t).topShape);
%         bottom_mu = muHistory(t). (regretD(t).bottomShape);
%         best_mu = max(top_mu, bottom_mu);
%         
%         if strcmp(regretD(t).choice, 'top')
%             chosen_mu = top_mu;
%         else
%             chosen_mu = bottom_mu;
%         end
%         
%         cum_regret = cum_regret + (best_mu - chosen_mu);  
%     end
% end
% fprintf('Cumulative Regret: %.2f\n', cum_regret);

% Mean Reaction Time
% valid_RT = [regretD.RT];
% valid_RT = valid_RT(~isnan(valid_RT));
% mean_RT = mean(valid_RT);
% fprintf('Mean Reaction Time: %.2f seconds\n', mean_RT);

% save('performance_metrics.mat', 'cum_regret','rankPercent');

%%

% Best_option_choice = sum(regretD.magRed > regretD.magPink, 'omitnan');
% Worse_option_choice = sum(regretD.magRed < regretD.magPink, 'omitnan');
% 
% isNoSelection = (regretD.magRed == regretD.magPink) | isnan(regretD.magPink) | isnan(regretD.magRed);
% numNoSelection = sum(isNoSelection);
% 
% perc_better = Best_option_choice / nTrials * 100;
% perc_worse  = Worse_option_choice  / nTrials * 100;
% perc_nochoice = numNoSelection  / nTrials * 100;
% 
% fprintf('You chose better option: %.2f%%\n', perc_better)
% fprintf('You chose worse option: %.2f%%\n', perc_worse)
% fprintf('You did not chose: %.2f%%\n', perc_nochoice)
