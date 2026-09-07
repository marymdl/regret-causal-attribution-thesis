function nll = ql_negloglik(theta, raw, model_type,half_trial)
%   Negative log-likelihood of choice data under the hybrid
%   regret/relief learning model, for ONE subject's cached raw data.
%
%   theta       : unconstrained parameter vector (transformed internally
%                 so alphas stay in (0,1) via sigmoid, beta stays >0 via exp)
%                 unconstrained means they're not limited between 0,1 . 
%   raw         : struct from load_subject_raw.m (fields part1, part2)
%   model_type  : 1 = reward-only but different lr for real & counterfactual rwd(M1, 3 free params: alpha_R, alpha_F, beta)
%                 2 = symmetric counterfactual (M2, 4 params: + alpha_C)
%                 3 = asymmetric counterfactual (M3, 5 params: alpha_regret, alpha_relief)

    sigmoid = @(x) 1./(1+exp(-x));

    alpha_R = sigmoid(theta(1));
    alpha_F = sigmoid(theta(2));

    switch model_type
        case 1
            alpha_regret = 0; alpha_relief = 0;
            beta = exp(theta(3)); % To make sure temperature stay positive / beta is the last param in theta lists.
        case 2
            alpha_C = sigmoid(theta(3));
            alpha_regret = alpha_C; alpha_relief = alpha_C;
            beta = exp(theta(4));
        case 3
            alpha_regret = sigmoid(theta(3));
            alpha_relief = sigmoid(theta(4));
            beta = exp(theta(5));
        otherwise
            error('model_type must be 1, 2, or 3');
    end

    Q = struct('circle',0,'square',0,'triangle',0);
    nll = 0;

    for part = 1:2
        R = raw.(['part' num2str(part)]);
        n = R.n;

        for t = 2:n
            if isempty(R.chosenShape{t-1}) || isempty(R.choice{t})  % *** check these conditions later ***
                continue;
            end
            armTop    = R.topShape{t};
            armBottom = R.bottomShape{t};
            
            have_update = ~isnan(R.mag_chosen(t)) && ~isnan(R.mag_notChosen(t));
            saw_feedback = ~isnan(R.RT_all(t)) && R.RT_all(t) > half_trial;
            % local function handle to compute choice log-likelihood with
            % whatever Q currently holds
            eval_choice = @() local_choice_ll(Q, armTop, armBottom, beta, R.choice{t});
            
            %% ---- update Q from feedback about trial t-1, revealed at t ----
            if have_update
                c = R.chosenShape{t-1};
                if strcmp(c, R.topShape{t-1})
                    u = R.bottomShape{t-1};
                else
                    u = R.topShape{t-1};
                end
                Rc = R.mag_chosen(t);
                Ru = R.mag_notChosen(t);
            end
            
            %% ---- fast response (didn't see feedback yet): evaluate choice BEFORE the update ----
            if ~saw_feedback
                nll = nll - eval_choice();
            end
            if have_update
                Q.(c) = Q.(c) + alpha_R*(Rc - Q.(c)) - alpha_regret*max(0, Ru-Rc); 
                % We update the value of chosen shape in two ways: 1)real
                % rwd 2) regret of chosing the worse uption
                Q.(u) = Q.(u) + alpha_F*(Ru - Q.(u)) - alpha_relief*max(0, Rc-Ru);
                % We update the value of unchosen shape in two ways: 1)real
                % rwd for unchosen shape 2) relief of not chosing this
                % shape
            end
             %% ---- slow response (saw feedback already): evaluate choice
            %       AFTER the update ----
            if saw_feedback
                nll = nll - eval_choice();
            end


        end
           
          %  nll = nll - (y*log(p_top) + (1-y)*log(1-p_top)); % the error 
    end
end
    
function ll = local_choice_ll(Q, armTop, armBottom, beta, choice_str)
        %% ---- predict choice at trial t using CURRENT Q ----
    % now that we updated the value of each shape, predict the
    % choise of top
    Vtop = Q.(armTop); 
    Vbot = Q.(armBottom);
    p_top = 1/(1+exp(-beta*(Vtop-Vbot))); %soft max
    p_top = min(max(p_top, 1e-6), 1-1e-6); %to avoid soft max giving absolute 0 or 1( it ruins log l)
    y = strcmp(choice_str, 'top');
    ll = y*log(p_top) + (1-y)*log(1-p_top);
end

