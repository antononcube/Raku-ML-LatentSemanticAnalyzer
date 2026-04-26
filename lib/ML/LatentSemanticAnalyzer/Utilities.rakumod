use v6.d;

unit module ML::LatentSemanticAnalyzer::Utilities;

#| Get a dataset with conference abstracts. Returns an array of hashmaps.
our sub get-abstracts-dataset() {
    my $fileResource = %?RESOURCES<dfAbstracts.csv>;

    my @lines = slurp($fileResource).subst('"', :g).lines;
    my @keys = @lines.head.split(',', :skip-empty).Array;
    my @tbl = do for @lines.tail(*-1).grep(*) -> $line {
        (@keys Z=> $line.split(',', :skip-empty).Array).Hash
    }
    return @tbl;
}
#= Ingests the resource file "dfAbstracts.csv" of ML::LatentSemanticAnalyzer.

