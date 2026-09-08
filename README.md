# Regret and Credit Assignment in Reward Based Learning

Computational and behavioral analysis of how regret and relief signals from
counterfactual feedback shape credit assignment in a three-armed bandit task
with a random-reward misattribution manipulation.

## Overview

This repository contains the analysis pipeline for my Master's thesis, which
tests whether:
1. Regret (a rectified comparison between the chosen and forgone option)
   predicts choice independently of raw reward values.
2. Regret and relief have dissociable temporal dynamics (amplitude and decay).
3. This dissociation is captured by a hybrid counterfactual Q-learning model.
4. Individual differences in these computational parameters relate to
   self-report measures of uncertainty intolerance, impulsivity, and mood.

## Repository structure

- `src/` — reusable functions (data loading, table-building, model
  likelihood/simulation functions).
- `analysis/` — numbered scripts that reproduce each analysis stage, in order.
- `docs/methodology.md` — full written methodology.(the task's code is also included)
- `results/figures/` — final figures used in the thesis.

## Requirements

### Task implementation
- MATLAB (R2015b or later)
- Psychtoolbox-3

### Data analysis
- Statistics and Machine Learning Toolbox (`fitglm`, `fitglme`, `fitnlm`)

### Model fitting
- No additional toolboxes required (uses `fminsearch` from base MATLAB)

## How to reproduce

1. Place raw `*_results.mat` files in a local `data/raw/` folder
2. Update `basePath` at the top of each script in `analysis/` to point to
   your local data folder.
3. Move the function files(in 'scr') to the same folder as the analysis files.
4. Run the scripts in `analysis/` in numbered order.

## Data availability

Raw behavioral data are not included in this repository to protect
participant confidentiality. De-identified summary data may be made
available upon reasonable request / after ethics-board approval for sharing.

## Citation

If you use this code, please cite:
[not available yet]
