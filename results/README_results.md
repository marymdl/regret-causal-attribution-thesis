# Results

This page summarizes the findings so far.

At the group level, participants achieved a mean accuracy of *67%*. Accuracy was defined as selecting the option with the highest expected value (i.e., the highest current underlying mean reward) on each trial.
<img width="1200" height="900" alt="mu_based_accuracy" src="https://github.com/user-attachments/assets/5cf89990-de65-4100-9c39-273011ab0d2f" />

[ z score? ]


## 1. Regret predicts choice independently of raw reward value

**Question:** Does credit assignment rely purely on the raw experienced value
of the chosen and forgone options, or does it also incorporate an explicit
counterfactual comparison(regret)?

A mixed-effects logistic regression comparing a reward-only model
(`Reward_chosen` + `Reward_notchosen`, lags 1-6) against a model that adds
`Regret_chosen` showed that adding regret significantly improved model fit
(likelihood-ratio test). This result held after controlling for random-reward misattribution terms and was
consistent at the individual-subject level for a majority of participants.

<img width="1200" height="900" alt="reward_vs_regret_coefficients" src="https://github.com/user-attachments/assets/403ec5bf-68ab-4363-9764-8775b0eaafb3" />
figure1.Coefficient plot (Reward + Regret model)



<img width="1200" height="900" alt="reward_vs_regret_lrt" src="https://github.com/user-attachments/assets/271139ed-3eea-47bc-aa17-c470468cb39b" />
figure2. Reward vs. Reward + Regret model comparison.


<img width="1200" height="900" alt="reward_vs_regret_incremental_value" src="https://github.com/user-attachments/assets/bf301f15-09ec-46bb-821e-33d4f6060442" />
figure3. Reward vs. Reward + Regret incremental value


---

## 2. Regret and relief are asymmetric in amplitude

**Question:** Does regret (loss from the chosen option) have a different
magnitude of effect than relief (avoided loss from the forgone option)?

After identifying and correcting a structural collinearity issue (including
`Reward_chosen` alongside its own derived term `Regret_chosen` destabilized
higher-lag coefficients), a clean model with only `Regret_chosen` and
`Relief_notchosen` (lags 1-6, no raw `Reward_chosen`) showed:

- At lag 1, |β(Regret)| > |β(Relief)| (Wald contrast z=7.37, p<0.00001)
- At lags 3, 4, and 6, the direction reverses: |β(Relief)| > |β(Regret)|
  (all p<0.05 after Bonferroni correction for 6 comparisons; lag 5 did not
  survive correction)
- Per-subject paired t-test on |β(Regret_L1)| vs |β(Relief_L1)|: t(37)=3.92,
  p=0.0004

<img width="1200" height="900" alt="reward relief_magnitude_comparison" src="https://github.com/user-attachments/assets/690e92a7-29f2-44a6-a950-49c07ffbac4f" />
<img width="1200" height="900" alt="reward relief_B_comparison" src="https://github.com/user-attachments/assets/43a4ad4c-8b2a-4e47-9be3-5a81d6eab8f9" />
figure4. reward & relief magnitude comparison

---

## 3. Regret and relief have dissociable decay time-constants

**Question:** Beyond amplitude, do regret and relief operate on different
timescales?

An exponential decay curve (β_k = A·exp(-(k-1)/τ)) was fit separately to the
regret and relief lag-coefficients:

| | Amplitude (A) | Time constant (τ, in choice-events) | Half-life |
|---|---|---|---|
| Regret | -0.055 | 1.22 | 0.85 |
| Relief | -0.036 | 3.21 | 2.22 |

A subject-level bootstrap (2000 resamples) on τ(relief) − τ(regret) gave a
mean difference of 1.79 events, 95% CI [1.11, 2.73], p<0.0001. Regret
produces a larger but more transient effect; relief produces a smaller but
more persistent one.

**Figure:** `figures/04_decay_curve_fit.png` — observed points + fitted
exponential curves for both pathways.
**Figure:** `figures/05_bootstrap_tau_difference.png` — bootstrap
distribution of the τ difference.

---

## 4. A hybrid counterfactual Q-learning model recovers the same asymmetry

**Question:** Can this dissociation be captured by an explicit trial-by-trial
learning model, rather than only by post-hoc lag regression?

A hybrid model was built where the chosen arm is updated via a standard
reward-prediction-error term plus a rectified regret penalty, and the
forgone arm is updated via a fictive-learning term plus a rectified relief
penalty (see `docs/methodology.md` for full equations). Three nested models
were compared:

- **M1** (reward-only) vs **M2** (symmetric counterfactual): ΔAIC ≈ 35-38,
  p<0.00001 — counterfactual learning is clearly present.
- **M2** vs **M3** (asymmetric counterfactual): a small number of outlier
  subjects (likely local optima in the 5-parameter fit) initially made the
  group-level paired t-test on AIC non-significant (p≈0.05) despite a
  majority of subjects (29 of 43) being individually best fit by M3. A
  Wilcoxon signed-rank test (robust to outliers) confirmed the direction is
  reliable.
- Fitted M3 parameters: mean α(regret) = 0.27-0.28, mean α(relief) =
  0.61-0.66, paired t-test p<0.00001 — consistent with the regression-based
  amplitude asymmetry.
- This result was **robust to adding a reaction-time-based correction**
  for whether feedback was seen before or after the response was made,
  which changed the fitted parameters negligibly — the asymmetry is not an
  artifact of that timing assumption.

**Figure:** `figures/06_QL_model_comparison_AIC.png` — per-subject AIC
comparison across M1/M2/M3.
**Figure:** `figures/07_alpha_regret_vs_relief.png` — fitted α(regret) vs
α(relief) per subject.

---

## 5. Methodological checks and negative findings

Several exploratory directions were tested and explicitly ruled out or
flagged as unreliable - documented here for transparency:

- **Individual-subject estimation of the cumulative-regret decay rate (α)**
  was found to be largely unidentifiable: a permutation control (shuffling
  regret values) reproduced the same bimodal clustering of "best-fit α"
  seen in the real data, showing this pattern is a structural artifact of
  the grid-search/optimizer, not a real individual difference. **This
  measure should not be used for individual-differences analyses.**
- A suspected exact algebraic collinearity between `Regret_chosen` and the
  raw reward terms (based on the rectified definition of regret) was tested
  directly via conditional correlation and **not confirmed** — the
  instability in higher-lag coefficients is better explained by ordinary
  (moderate) collinearity combined with weak signal at longer lags, not a
  hidden exact redundancy.
- Within-subject z-scoring of all lag predictors did not change the
  correlation structure, indicating the (moderate) collinearity among
  predictors is a genuine within-subject phenomenon, not an artifact of
  pooling across subjects with different response scales.

---

## 6. Ongoing / planned analyses

- Parameter recovery study for the Q-learning model parameters (checking
  identifiability of α(regret), α(relief), α_R, α_F).
- Correlating individual model parameters (once validated via recovery)
  with self-report questionnaires: Intolerance of Uncertainty Scale (IUS-12),
  Carver & White BIS/BAS, Wechsler Digit Span, Beck Depression Inventory,
  Spielberger STAI, and Barratt Impulsiveness Scale (BIS-11).
- Formal test of whether random-reward misattribution moderates the
  cumulative regret effect on choice.

See `analysis/` for the numbered scripts reproducing each of the above.
