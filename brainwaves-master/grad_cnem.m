function out=grad_cnem(XYZ,V,IN_Tri_Ini)
%  gradV = grad_cnem(XYZ,V,[IN_Tri_Ini])
% Gradient \nabla V evaluated at 3-D scattered points in matrix XYZ
%
% Alternatively, can call 
%  gradV = grad_cnem(B,V);
% to use a precalculated B matrix
%
% Uses CNEM.
%
%
% JA Roberts, QIMR Berghofer, 2018

if nargin<3
    IN_Tri_Ini=[];
end

if size(XYZ,2)==3 % if loc matrix, calculate the B matrix
    B = grad_B_cnem(XYZ,IN_Tri_Ini);
else % already given the B matrix
    B=XYZ;
end

Grad_V=B*V;
Grad_V_mat=reshape(Grad_V,4,[]).';
% reshape è una funzione nativa di MATLAB.
% Cosa fa: Prende il vettore Grad_V e lo ridispone in una matrice con 4 righe.
% Perché 4?: Il metodo C-NEM calcola per ogni punto quattro valori: la derivata rispetto a $x$, quella rispetto a $y$, quella rispetto a $z$ e, solitamente, il valore della funzione originale filtrato (o una quarta componente di errore/interpolazione).
% .': È l'operatore di trasposizione (scambia righe con colonne).

out=Grad_V_mat(:,1:3); % 4th column is V
% Anche questa è un'operazione standard di indicizzazione di MATLAB.
% Prende tutte le righe (:) ma solo le prime tre colonne (1:3).
% In questo modo, "scarta" la quarta colonna di servizio e ti restituisce solo i vettori spaziali $\nabla \phi = [\frac{\partial \phi}{\partial x}, \frac{\partial \phi}{\partial y}, \frac{\partial \phi}{\partial z}]$.