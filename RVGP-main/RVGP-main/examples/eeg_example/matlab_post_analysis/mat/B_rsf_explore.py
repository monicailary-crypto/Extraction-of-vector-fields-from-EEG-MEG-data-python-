import scipy.io
import os

# 1. Determine the script's directory
script_dir = os.path.dirname(os.path.abspath(__file__))
#print(f"The script is running in: {script_dir}")

# 2. List all files in the directory to check if the .mat file exists
files_in_dir = os.listdir(script_dir)
#print(f"Files found in this directory: {files_in_dir}")

# 3. Attempt to load the file using its full path
file_name = 'B_rsf.mat'
full_path = os.path.join(script_dir, file_name)

if file_name in files_in_dir:
    try:
        content = scipy.io.loadmat(full_path)
        #print("\n--- FILE LOADED SUCCESSFULLY! ---")
        print("Variables contained:")
        for key in content.keys():
            if not key.startswith('__'):
                print(f"- {key}")

        # Extract the specific variable
        matrix_B = content['B_rsf']
        
        print(f"\n--- 'B_rsf' Analysis ---")
        print(f"Data type: {type(matrix_B)}")
        print(f"Dimensions (Shape): {matrix_B.shape}")

        # Count non-zero elements
        print(f"Non-zero elements: {matrix_B.nnz}")
        density_percentage = (matrix_B.nnz / (1024 * 256)) * 100
        print(f"Matrix density: {density_percentage:.2f}%")

        # Convert to a standard dense matrix to preview a small sample
        dense_matrix_preview = matrix_B.tocsr()[:5, :5].toarray()
        print(f"Top-left corner (5x5):\n{dense_matrix_preview}")

    except Exception as e:
        print(f"Error during loading: {e}")
else:
    print(f"\nERROR: The file '{file_name}' was NOT found in the directory!")
    print(f"Move the .mat file into: {script_dir} and try again.")