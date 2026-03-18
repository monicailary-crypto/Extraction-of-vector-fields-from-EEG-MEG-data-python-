function v=phaseflow_cnem(yphasep,loc,dt,speedonlyflag)
%  v = phaseflow_cnem(yphasep,loc,dt)
% Calculate instantaneous phase flow at every time point
%
% Inputs: yphasep - times-by-regions matrix of phases (channels), assumed unwrapped
%         loc - regions-by-3 matrix of points
%         dt - time step
% 
% Outputs: v - velocity struct, with fields:
%            -- vnormp - speed
%            -- vxp - x component
%            -- vyp - y component
%            -- vzp - z component
%
% JA Roberts, QIMR Berghofer, 2018

% nargin = Number of Input Arguments
% The speedonlyflag parameter acts as a switch (a "flag"): 
% If it is 0 (Default): The function calculates both the speed (norm) and all directional components ($x, y, z$) of the neural stream. 
% If it is 1: The function calculates only the speed magnitude, saving computation time or avoiding generating unnecessary directional data.
if nargin<4
    speedonlyflag=0;
end

% assume phases unwrapped in time already
[~,dphidtp]=gradient(yphasep,dt);
% [~, dphidtp]: MATLAB restituisce il gradiente lungo le colonne (spaziale) e lungo le righe (temporale). 
% Il simbolo ~ indica che il gradiente spaziale viene scartato, mentre dphidtp memorizza la variazione della fase nel tempo ($\frac{\partial \phi}{\partial t}$).
fprintf('dphidt done...')
% Matematicamente, la variazione della fase nel tempo corrisponde alla frequenza istantanea del segnale in quel preciso momento per quel determinato elettrodo.
% Se la fase cambia molto velocemente, significa che l'oscillazione neuronale in quel punto è rapida.
% Questo valore verrà poi diviso per il gradiente spaziale (nelle righe successive del codice) per ottenere la velocità di propagazione dell'onda ($v = \frac{\partial \phi / \partial t}{\|\nabla \phi\|}$).

shpalpha=30; % alpha radius; may need tweaking depending on geometry
% Definisce il raggio di ricerca per l'algoritmo. 
% L'Alpha-radius determina quanto "aderente" deve essere l'involucro che avvolge i tuoi punti.
% Se il valore è troppo piccolo, la forma si rompe in tanti pezzi separati.
% Se è troppo grande, la forma diventa un unico blocco convesso (come se avessi teso un elastico intorno ai punti), perdendo i dettagli della curvatura cranica.
shp=alphaShape(loc,shpalpha);
% alphaShape crea un oggetto Alpha Shape, ovvero una rappresentazione geometrica 3D che racchiude i punti specificati in loc (le coordinate degli elettrodi). 
% In pratica, "unisce i puntini" per creare un volume solido che rappresenta la testa del soggetto.
bdy=shp.boundaryFacets;
% Una volta creata la forma solida, questa riga ne estrae solo la superficie esterna (il "guscio").
% bdy (boundary facets) contiene l'elenco dei triangoli che compongono la superficie esterna del volume.
% È un passaggio critico perché l'attività EEG che misuri avviene sulla superficie della corteccia/scalpo, quindi il flusso delle onde deve essere calcolato seguendo questa superficie, non passando "dentro" la testa.
B=grad_B_cnem(loc,bdy);
% grad_B_cnem (che è un'utility specifica di cnem) calcola la matrice degli operatori di gradiente.
% Utilizza le posizioni degli elettrodi (loc) e le connessioni della superficie (bdy) per pre-calcolare come la fase cambia nello spazio.
% Il risultato B è una matrice che verrà usata nelle righe successive per trasformare la fase di ogni elettrodo in un vettore di flusso ($x, y, z$).
% B è una matrice di pesi geometrici basata sulla posizione degli elettrodi (loc) e sulla loro connessione superficiale (bdy).
% Non dipende dai dati EEG: Viene calcolata una sola volta all'inizio dello script perché la posizione degli elettrodi sulla testa non cambia durante l'esperimento.
% È un operatore di gradiente: In analisi numerica, quando hai punti sparsi (come gli elettrodi sulla testa), non puoi fare una derivata semplice come in analisi 1. 
% Hai bisogno di una matrice che metta in relazione ogni punto con i suoi vicini.
% B = Lo strumento di calcolo (fisso).
% yphasor = I tuoi dati (variabili nel tempo).
% gradphasor = Il risultato (le derivate spaziali della fase).
np=size(yphasep,1);
% serve a determinare la durata temporale del tuo esperimento, ovvero quanti istanti di tempo (punti campionati) devono essere analizzati.
% Ecco il dettaglio tecnico:
% yphasep: È la matrice che contiene le fasi estratte dai segnali EEG. Come abbiamo visto prima, questa matrice è organizzata con il tempo sulle righe e i canali (elettrodi) sulle colonne.
% size(..., 1): In MATLAB, questa funzione restituisce la dimensione della prima dimensione di una matrice, che corrisponde sempre al numero di righe.
% np: È il nome della variabile (abbreviazione di Number of Points) in cui viene salvato questo valore.

dphidxp=zeros(size(yphasep));
dphidyp=zeros(size(yphasep));
dphidzp=zeros(size(yphasep));

for j=1:np
    % righe: tempi
    % colonne: canali
    yphase=yphasep(j,:);    %Estrae la riga j-esima della matrice delle fasi. In pratica, prende la "fotografia" della fase di tutti gli elettrodi in un unico millesimo di secondo.
    yphase=yphase(:);   % Trasforma la riga in un vettore colonna per prepararlo alle operazioni matriciali successive.
    
    % wrap phases by differentiating exp(i*phi)
    yphasor=exp(1i*yphase); %Invece di lavorare direttamente con gli angoli (che hanno il problema del salto da $+\pi$ a $-\pi$), il codice proietta ogni fase sul cerchio unitario del piano complesso.$e^{i\phi}$: Questo trasforma la fase in un numero complesso chiamato fasore. È un passaggio fondamentale: derivare un angolo "saltellante" è difficile, derivare un vettore che ruota in modo fluido è matematicamente stabile.
    gradphasor=grad_cnem(B,yphasor);    % La funzione grad_cnem applica la geometria della testa ai dati EEG del momento $j$.gradphasor: È una matrice che contiene la variazione spaziale del fasore nelle tre dimensioni ($x, y, z$).
    
    % Queste tre righe servono a "tornare indietro" dal mondo dei numeri complessi (fasori) a quello dei radianti (fase), applicando una proprietà matematica delle derivate dei logaritmi complessi:
    dphidxp(j,:)=real(-1i*gradphasor(:,1).*conj(yphasor));
    dphidyp(j,:)=real(-1i*gradphasor(:,2).*conj(yphasor));
    dphidzp(j,:)=real(-1i*gradphasor(:,3).*conj(yphasor));
    % Logica matematica: Se $z = e^{i\phi}$, allora la derivata della fase è $\nabla \phi = \text{Re}(-i \cdot \frac{\nabla z}{z})$. Poiché il modulo di $z$ è 1, $1/z$ è uguale al coniugato $\bar{z}$ (conj(yphasor)).
    % Risultato: dphidxp, dphidyp e dphidzp ora contengono le componenti del vettore gradiente della fase ($\nabla \phi$).
end
fprintf('gradphi done...')

normgradphip=sqrt(dphidxp.^2+dphidyp.^2+dphidzp.^2);
% magnitude of velocity = dphidt / magnitude of grad phi, as per Rubino et al. (2006)
vnormp=abs(dphidtp)./normgradphip;

v.vnormp=vnormp;
if ~speedonlyflag   %speedonlyflag = 0
    v.vxp=vnormp.*-dphidxp./normgradphip; % magnitude * unit vector component
    v.vyp=vnormp.*-dphidyp./normgradphip;
    v.vzp=vnormp.*-dphidzp./normgradphip;
end
fprintf('v done...')
