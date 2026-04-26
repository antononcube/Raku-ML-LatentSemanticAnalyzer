use ML::LatentSemanticAnalyzer;
use Lingua::EN::Stem::Porter;

# Collection of texts
my @dsAbstracts = get-abstracts-dataset();
my %docs = @dsAbstracts.map(*<ID>) Z=> @dsAbstracts.map(*<Abstract>);
say %docs.elems;

# Remove non-strings
my %docs2 = %docs.grep({ $_.value ~~ Str:D });
say %docs2.elems;

# Stemmer object (to preprocess words in the pipeline below)
say &porter.WHY;

# Words to show statistical thesaurus entries for
my @words = <notebook computational function neural talk programming>;

# Reproducible results (just within a session)
srand(12);

# LSA pipeline
my $lsaObj =
        LatentSemanticAnalyzer.new
                .make-document-term-matrix(docs => %docs2, :stop-words, :stemming-rules, :3min-length)
                .apply_term_weight_functions(global-weight-func => "IDF", local-weight-func => "None", normalizer-func => "Cosine")
                .extract-topics(:40number-of-topics, :10min-number-of-documents-per-term, method => "SVD")
                .echo-topics-interpretation(:12number-of-terms, :!wide-form)
                .echo_statistical_thesaurus(terms => @words.map(*.&porter), :wide-form, :12number-of-nearest-neighbors, method => "cosine");

say $lsaObj;