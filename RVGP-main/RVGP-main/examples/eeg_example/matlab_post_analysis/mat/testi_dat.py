import scipy.io
import os

# 1. Capiamo dove si trova questo script
cartella_script = os.path.dirname(os.path.abspath(__file__))
print(f"Lo script sta girando in: {cartella_script}")

# 2. Elenchiamo i file presenti nella cartella per vedere se il .mat è lì
file_nella_cartella = os.listdir(cartella_script)
print(f"File trovati in questa cartella: {file_nella_cartella}")

# 3. Cerchiamo di caricare il file usando il percorso completo
nome_file = 'B_rsf.mat'
percorso_completo = os.path.join(cartella_script, nome_file)

if nome_file in file_nella_cartella:
    try:
        contenuto = scipy.io.loadmat(percorso_completo)
        print("\n--- FILE CARICATO CON SUCCESSO! ---")
        print("Variabili contenute:")
        for chiave in contenuto.keys():
            if not chiave.startswith('__'):
                print(f"- {chiave}")

        # Estraiamo la variabile specifica
        matrice_B = contenuto['B_rsf']
        
        print(f"\n--- Analisi di 'B_rsf' ---")
        print(f"Tipo di dato: {type(matrice_B)}")
        print(f"Dimensioni (Shape): {matrice_B.shape}")

        # Quanti elementi non sono zero?
        print(f"Elementi non nulli: {matrice_B.nnz}")
        percentuale = (matrice_B.nnz / (1024 * 256)) * 100
        print(f"Densità della matrice: {percentuale:.2f}%")

        # Convertila in una matrice densa "normale" solo se vuoi vedere un pezzetto
        matrice_densa = matrice_B.tocsr()[:5, :5].toarray()
        print(f"Angolo in alto a sinistra (5x5):\n{matrice_densa}")


    except Exception as e:
        print(f"Errore durante il caricamento: {e}")
else:
    print(f"\nERRORE: Il file '{nome_file}' NON è nella cartella!")
    print(f"Sposta il file .mat dentro: {cartella_script} e riprova.")