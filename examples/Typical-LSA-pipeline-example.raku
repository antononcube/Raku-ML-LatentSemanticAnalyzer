use ML::LatentSemanticAnalyzer;
use ML::LatentSemanticAnalyzer::Utilities;
use Lingua::EN::Stem::Porter;

# Collection of texts
my @dsAbstracts = ML::LatentSemanticAnalyzer::Utilities::get-abstracts-dataset();

# Remove non-strings
@dsAbstracts .= grep({ $_<Abstract> ~~ Str:D });

say "@dsAbstracts.elems : {@dsAbstracts.elems}";
my %docs = @dsAbstracts.map(*<ID>) Z=> @dsAbstracts.map(*<Abstract>);
say "%docs.elems : {%docs.elems}";

# Stemmer object (to preprocess words in the pipeline below)
#say &porter.WHY;

# Words to show statistical thesaurus entries for
my @words = <notebook computational function neural talk programming>;

# Reproducible results (just within a session)
srand(12);

my &echo-function = {.say for |$_};

my $tStart = now;
my %stemming-rules = %docs.values.join(' ').lc.split(/\s | <:punct> /, :skip-empty)>>.trim.unique.map({ $_ => porter($_) });
my $tEnd = now;
say "time to compute stemming rules : {$tEnd - $tStart}";

#.say for |%stemming-rules;

# LSA pipeline
$tStart = now;
my $lsaObj =
        ML::LatentSemanticAnalyzer.new
                .make-document-term-matrix(docs => %docs, :stop-words, :%stemming-rules, :3min-length)
                .apply-term-weight-functions(global-weight-func => "IDF", local-weight-func => "None", normalizer-func => "Cosine")
                .extract-topics(:40number-of-topics, :10min-number-of-documents-per-term, method => "SVD")
                .echo-topics-interpretation(:12number-of-terms, :wide-form, :dataset, :&echo-function)
                .echo-statistical-thesaurus(terms => @words.map({ porter($_) }), :wide-form, :12number-of-nearest-neighbors, method => "euclidean", :&echo-function);
say "time to run LSA pipeline : {$tEnd - $tStart}";

say $lsaObj;