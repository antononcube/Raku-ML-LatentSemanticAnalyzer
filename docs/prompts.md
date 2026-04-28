
## Re-implementation of the Python package "LatentSemanticAnalyzer"

> - Implement the Raku package "ML::LatentSemanticAnalyzer" based on the Python package "LatentSemanticAnalyzer"
> with code placed in the directory "./Python/LatentSemanticAnalyzer".
> - For the sparse matrix operations use the operations of "Math::SparseMatrix" -- see the file "./lib/Math/SparseMatrix.rakumod".
> - For the document-term creations and functions use the role `ML::SparseMatrixRecommender::DocumentTermWeightish` -- see the file "./lib/ML/SparseMatrixRecommender/DocumentTermWeightish.rakumod"
> - Your new implementation code should be only in the directory "./lib/ML/LatentSemanticAnalyzer" and the file "./lib/ML/LatentSemanticAnalyzer.rakumod".
> - Use kebab case for all method names and argument names.
> - Do not implement SVD and NNMF. Do not implement new sparse matrix functionalities.


## Unit tests

> Convert the Python tests in "./tests" into Raku tests in "./t". Use the same file names.