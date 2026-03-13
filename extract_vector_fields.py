import mne
import numpy as np
from RVGP.dataclass import data as RVGPData
from RVGP.geometry import project_to_manifold
import matplotlib.pyplot as plt

# --- 1. CARICAMENTO DATI ---
fname = r"C:\Users\monic\Documents\GitHub\Extraction-of-vector-fields-from-EEG-MEG-data-python-\ds004504\sub-001\eeg\sub-001_task-eyesclosed_eeg.set"
raw = mne.io.read_raw_eeglab(fname, preload=True)

# Estrazione coordinate X (19, 3)
montage = raw.get_montage()
pos_dict = montage.get_positions()['ch_pos']
X = np.array([pos_dict[ch] for ch in raw.ch_names if ch in pos_dict])

# Estrazione segnale (19, Tempi)
eeg_data = raw.get_data(picks='eeg')

# --- 2. CREAZIONE MANIFOLD RVGP ---
# n_eigenpairs=18 perché abbiamo 19 elettrodi (N-1)
d = RVGPData(vertices=X, n_neighbors=5, n_eigenpairs=18)

# --- 3. TRASFORMAZIONE IN VETTORI (VECTORS) ---
# Esempio: prendiamo il primo istante temporale
v_scalar = eeg_data[:, 0] 

# Per RVGP servono vettori 3D (nx3). 
# Un modo semplice è usare il voltaggio come componente 'Z' 
# o calcolare il gradiente spaziale. 
# Qui creiamo un campo vettoriale fittizio basato sul voltaggio per test:
dummy_vectors = np.zeros_like(X)
dummy_vectors[:, 2] = v_scalar  # Mettiamo il voltaggio sulla componente verticale

# Proiettiamo i vettori sulla superficie della testa (sui tangent spaces)
# Questa è la funzione che RVGP usa internamente!
d.vectors = project_to_manifold(dummy_vectors, d.gauges)

print(f"\nGeometria e Vettori pronti!")
print(f"Vettori proiettati (shape): {d.vectors.shape}")

# --- 4. VISUALIZZAZIONE 3D ---
from RVGP.plotting import create_axis
fig, ax = create_axis(3)
ax.scatter(X[:, 0], X[:, 1], X[:, 2], color='red', label='Elettrodi')

# Disegnamo i vettori (frecce)
ax.quiver(X[:, 0], X[:, 1], X[:, 2], 
          d.vectors[:, 0], d.vectors[:, 1], d.vectors[:, 2], 
          length=0.01, color='blue', label='Flusso segnale')

ax.set_title("Elettrodi e Campi Vettoriali sulla Manifold")
plt.legend()
plt.show()