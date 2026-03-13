import mne
import numpy as np
import RVGP
from RVGP import geometry
import networkx as nx
from RVGP.dataclass import data as RVGPData

# 1. Carica il file .set (EEGLAB)
fname = r"C:\Users\monic\Documents\GitHub\Extraction-of-vector-fields-from-EEG-MEG-data-python-\ds004504\sub-001\eeg\sub-001_task-eyesclosed_eeg.set"
raw = mne.io.read_raw_eeglab(fname, preload=True)

# 2. ESTRAZIONE DI X (Posizioni elettrodi)
# Recuperiamo il montaggio (le coordinate 3D)
montage = raw.get_montage()
if montage is None:
    print("Attenzione: Il file non ha un montaggio. Devi caricarne uno standard.")
    # Esempio: raw.set_montage('standard_1020')
    # montage = raw.get_montage()

# Otteniamo le posizioni in un array (N_elettrodi, 3)
pos_dict = montage.get_positions()['ch_pos']
# Filtriamo solo per i canali EEG (escludendo EOG, referenze, ecc.)
X = np.array([pos_dict[ch] for ch in raw.ch_names if ch in pos_dict])

# 3. ESTRAZIONE DI VECTORS (Esempio: Segnale istantaneo o fase)
# RVGP lavora spesso con i gradienti. Per ora estraiamo i dati grezzi
# e vediamo come trasformarli in vettori tangenti.
data = raw.get_data(picks='eeg') # Shape: (Canali, Tempi)

# Esempio per un singolo istante temporale (es. il primo sample)
# Per RVGP, 'vectors' deve avere la stessa dimensione di X (N_elettrodi, 2 o 3)
sample_index = 0
v = data[:, sample_index] 

print(f"X estratto con successo: {X.shape} (Elettrodi, Coordinate)")
print(f"Dati estratti per il primo sample: {v.shape}")


# 4. CREAZIONE OGGETTO DATA (Il "Cuore" di RVGP)
# La classe 'data' fa tutto in automatico: grafo, tangent frames e Laplaciani.
# n_neighbors=5 è ottimo per 19 elettrodi.
try:
    d = RVGPData(vertices=X, n_neighbors=5, n_eigenpairs=10)
    
    print("\n--- VITTORIA! ---")
    print(f"Dimensione manifold predetta: {d.dim_man}")
    print(f"Frames (Gauges) calcolati: {d.gauges.shape}") # Dovrebbe essere (19, 3, 2)
    print(f"Laplaciano Connessione pronto: {d.Lc.shape}")
    
except Exception as e:
    print(f"Errore durante la creazione dell'oggetto RVGP: {e}")

# 5. PREPARAZIONE DEI VECTORS
# Ora che abbiamo l'oggetto 'd', possiamo assegnargli i tuoi dati EEG.
# Se 'v' è il tuo vettore di voltaggi (19,), RVGP può usarlo.
# Nota: RVGP lavora meglio se i vettori sono già nel piano tangente.
