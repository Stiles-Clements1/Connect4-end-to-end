Connect4 AI Project (MCTS Dataset + CNN/Transformer Models + Dockerized AWS Backend)
=====================================================================================

Project Summary
---------------
This project builds a Connect4 AI by:

1. Generating a large dataset of board states using Monte Carlo Tree Search (MCTS)
2. Training deep learning models (CNN and Transformer variants) to predict moves
3. Deploying a Dockerized Python backend on AWS Lightsail
4. Connecting a frontend so users can play Connect4 against the AI

The backend in this repo is designed to serve model predictions (and can be used with
Anvil Uplink). The training and evaluation workflow is documented in
`Optimization_Final_Task.ipynb`.


Main Files
----------
- `connect4_backend.py`
  Backend inference server (TensorFlow model loading, legal-move masking, optional
  Anvil callable).

- `Optimization_Final_Task.ipynb`
  End-to-end notebook for Connect4 engine, MCTS dataset generation, training CNN /
  Transformer models, evaluation vs MCTS, and model export.

- `Dockerfile`
  Builds the Python backend container image.

- `docker-compose.yml`
  Runs the backend container and mounts host files (including trained models) into the
  container.


How the AI Was Built (Notebook Workflow)
----------------------------------------
`Optimization_Final_Task.ipynb` includes the full training pipeline:

1. Connect4 game engine
   - Board representation: 6 rows x 7 columns
   - Move generation, apply move, win checking, terminal-state detection

2. Board encodings
   - Option A: single 6x7 grid with values in {-1, 0, +1}
   - Option B (default / preferred): 6x7x2 channels
     - channel 0 = current player's pieces (+1 perspective)
     - channel 1 = opponent pieces
   - Perspective flipping is used so training/inference is normalized to +1 perspective

3. MCTS-based label generation
   - Simple UCT MCTS is used to choose a strong move for each position
   - Dataset builder uses dedupe-voting:
     - repeated board states are grouped
     - votes are collected for the MCTS-selected move
     - final label is the most-voted move for each unique board
   - Random opening moves are used to diversify positions

4. Training data used in the notebook
   - Generated dataset example: `num_games=2300`, `sims_per_move=300`,
     `random_opening_moves=4`, `encoding="B"`
   - Saved as `X1.npy` and `y1.npy`
   - Base generated dataset shown in notebook: 54,711 samples
   - Merged with an additional pool (`mcts7500_pool.pickle`) to reach:
     - Total samples: 320,331
     - Train: 288,297
     - Validation: 32,034

5. Model experiments in notebook
   - Baseline CNN
   - Baseline Transformer
   - CNN v2 (batch normalization + stronger architecture + horizontal-flip augmentation)
   - Transformer v2 (conv stem + augmentation)

6. Evaluation
   - Models are evaluated against weaker MCTS opponents at different simulation counts
     (e.g., 20 / 50 / 100 sims)
   - The notebook includes win/loss/draw comparisons and plots
   - Results vary by run due to stochastic MCTS/training, but the notebook shows both
     CNN v2 and Transformer v2 as strong candidates

7. Model export
   - `.keras` exports used by the backend (e.g., `cnn_v2.keras`, `transformer_v2.keras`)
   - Notebook also includes `.h5` export examples


Backend Overview (`connect4_backend.py`)
----------------------------------------
What the backend does:

- Loads a TensorFlow/Keras model once and caches it in memory
- Accepts a Connect4 board state (`6x7`) and current player (`+1` or `-1`)
- Encodes the board (default encoding `"B"`)
- Runs model inference to get move probabilities
- Masks invalid columns (full columns cannot be chosen)
- Returns the best legal move (column index `0..6`)

Important backend details:

- Default model path in code:
  `/anvilfolder/ubuntu/main/transformer_v2.keras`

- CLI test mode:
  `python connect4_backend.py --test --model-path <path_to_model>`
  This predicts one move on an empty board and prints the result.

- Anvil integration:
  If `anvil-uplink` is installed, the script exposes `anvil_get_move(...)` as an
  `anvil.server.callable` and waits forever after connecting.

Security note:
- `connect4_backend.py` currently contains a placeholder string: `anvil.server.connect("API KEY")`
- Replace this with your real Anvil Uplink key before deployment
- Do not commit a real key into source control


Docker + AWS Lightsail Deployment
---------------------------------
This repo includes a Dockerized backend intended to run on an AWS Lightsail machine.

Files used:
- `Dockerfile`
- `docker-compose.yml`
- `requirements.txt`
- `connect4_backend.py`
- Trained model files (for example `transformer_v2.keras` and/or `cnn_v2.keras`)

What the Docker setup does:

- Uses `python:3.12`
- Installs Python dependencies from `requirements.txt`
- Copies `connect4_backend.py` into the image
- Creates `/anvilfolder` in the container
- Runs the backend script on container start

Compose setup:
- Service name: `anvil-uplink`
- Restart policy: `always`
- Host volume mount: `/home` -> `/anvilfolder`

This means host files under `/home/...` are visible inside the container under
`/anvilfolder/...`.

Important path note (AWS username differences):
- Your backend code currently expects model files under:
  `/anvilfolder/ubuntu/main/...`
- If your Lightsail instance uses a different home directory (for example
  `/home/bitnami/...`), update the paths in `connect4_backend.py` accordingly.


Deployment Steps (Typical)
--------------------------
1. Copy these files to your Lightsail instance project folder:
   - `Dockerfile`
   - `docker-compose.yml`
   - `requirements.txt`
   - `connect4_backend.py`
   - model files (`*.keras`)

2. Update `connect4_backend.py` before deploying:
   - Set the correct Anvil Uplink key
   - Confirm the model path matches your host path + Docker volume mapping

3. Build and start:
   - `sudo docker compose build`
   - `sudo docker compose up -d`

4. Check logs:
   - `sudo docker compose logs -f`

5. Stop the service when updating code/models:
   - `sudo docker compose down`


Local Testing (Without Docker)
------------------------------
Install dependencies (example):
- `pip install -r requirements.txt`

Run a local inference test:
- `python connect4_backend.py --test --model-path transformer_v2.keras`

If `anvil-uplink` is not available, the script prints:
- `Anvil not available. Use get_move locally.`


Expected Input/Output for Inference
-----------------------------------
Board format:
- 6x7 nested list or NumPy-compatible array
- Values:
  - `0` = empty
  - `+1` = one player
  - `-1` = the other player

Returned value:
- Integer column index `0..6` (best legal move)


Frontend Integration (High-Level)
---------------------------------
The frontend (not included in this repo) sends the current board state to the backend
and receives the AI's selected move. The backend is designed to support this through
the callable `anvil_get_move(...)` when run with Anvil Uplink.


Screenshot Placeholders (Add Later)
-----------------------------------
<img width="3827" height="1275" alt="image" src="https://github.com/user-attachments/assets/05498981-2d6e-4124-a844-739f7166e97b" />

Frontend lobby

<img width="3822" height="1540" alt="image" src="https://github.com/user-attachments/assets/00ab2bd9-15db-4314-b874-6bac4b6d5f2a" />

Frontend gameplay in progress showing moves from Transformer AI

<img width="3792" height="1742" alt="Docker screenshot" src="https://github.com/user-attachments/assets/ab1a281b-c27f-4c93-80a6-4d0c94049b78" />

AWS Lightsail terminal with `docker compose logs` showing the backend container running



Future Improvements
------------------------------
- Train the CNN and Transformer more to get better moves
- Add win chance calculation using Mote Carlo Tree Search on an active game
- Attempt this project on a more complex game like chess

