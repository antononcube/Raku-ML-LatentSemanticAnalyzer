use ML::LatentSemanticAnalyzer;
use ML::LatentSemanticAnalyzer::Utilities;
#use Lingua::EN::Stem::Porter;

# Collection of texts
my @dsAbstracts = ML::LatentSemanticAnalyzer::Utilities::get-abstracts-dataset();

# Remove non-strings
@dsAbstracts .= grep({ $_<Abstract> ~~ Str:D });

.say for @dsAbstracts.head(3);
my %docs = @dsAbstracts.map(*<ID>) Z=> @dsAbstracts.map(*<Abstract>);
say %docs.elems;

# Stemmer object (to preprocess words in the pipeline below)
#say &porter.WHY;

# Words to show statistical thesaurus entries for
my @words = <notebook computational function neural talk programming>;

# Reproducible results (just within a session)
srand(12);

my &echo-function = {.say for |$_};

# LSA pipeline
my $lsaObj =
        ML::LatentSemanticAnalyzer.new
                .make-document-term-matrix(docs => %docs, :stop-words, :!stemming-rules, :3min-length)
                .apply-term-weight-functions(global-weight-func => "IDF", local-weight-func => "None", normalizer-func => "Cosine")
                .extract-topics(:40number-of-topics, :10min-number-of-documents-per-term, method => "SVD")
                .echo-topics-interpretation(:12number-of-terms, :wide-form, :&echo-function)
                .echo-statistical-thesaurus(terms => @words, :wide-form, :12number-of-nearest-neighbors, method => "cosine", :&echo-function);

say $lsaObj;