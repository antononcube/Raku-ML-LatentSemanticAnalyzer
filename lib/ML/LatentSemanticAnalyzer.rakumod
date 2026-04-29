use v6.d;

use Math::SparseMatrix;
use ML::SparseMatrixRecommender::DocumentTermWeightish;
use ML::SparseMatrixRecommender;
use ML::LatentSemanticAnalyzer::Utilities;

class ML::LatentSemanticAnalyzer does ML::SparseMatrixRecommender::DocumentTermWeightish {
    has $.documents is rw;
    has Math::SparseMatrix $.doc-term-mat is rw;
    has Math::SparseMatrix $.weighted-doc-term-mat is rw;
    has @.terms is rw;
    has $.stop-words is rw;
    has $.stemming-rules is rw;
    has $.words-pattern is rw;
    has Math::SparseMatrix $!W;
    has Math::SparseMatrix $!H;
    has $.global-weights is rw;
    has $.local-weight-function is rw;
    has $.normalizer-function is rw;
    has $.method is rw;
    has $.value is rw;


    #======================================================
    # Creators
    #======================================================
    multi method new() {
        self.bless
    }

    multi method new($arg) {
        my $obj = self.bless;
        given $arg {
            when Math::SparseMatrix:D { $obj.set-document-term-matrix($_) }
            when Positional:D | Associative:D { $obj.set-documents($_) }
            default { die 'The argument is expected to be documents or a Math::SparseMatrix object.' }
        }
    }

    #======================================================
    # Takers
    #======================================================
    method take-documents() { $!documents }
    method take-document-term-matrix() { $!doc-term-mat }
    method take-doc-term-mat() { $!doc-term-mat }
    method take-weighted-document-term-matrix() { $!weighted-doc-term-mat }
    method take-weighted-doc-term-mat() { $!weighted-doc-term-mat }
    method take-terms() { @!terms }
    method take-stop-words() { $!stop-words }
    method take-stemming-rules() { $!stemming-rules }
    method take-words-pattern() { $!words-pattern }
    method take-w() { $!W }
    method take-h() { $!H }
    method take-global-term-weights() { $!global-weights }
    method take-local-weight-function() { $!local-weight-function }
    method take-normalizer-function() { $!normalizer-function }
    method take-method() { $!method }
    method take-value() { $!value }


    #======================================================
    # Setters
    #======================================================
    method set-documents($arg) {
        die 'The first argument is expected to be a list of strings or a hash of strings.'
                unless ML::LatentSemanticAnalyzer::Utilities::is-str-list($arg) || ML::LatentSemanticAnalyzer::Utilities::is-str-hash($arg);
        $!documents = $arg;
        self
    }

    method set-document-term-matrix(Math::SparseMatrix:D $arg) {
        $!doc-term-mat = $arg;
        @!terms = $arg.column-names.Array;
        self
    }

    method set-weighted-document-term-matrix(Math::SparseMatrix:D $arg) {
        $!weighted-doc-term-mat = $arg;
        @!terms = $arg.column-names.Array;
        self
    }

    method set-global-term-weights($arg) { $!global-weights = $arg; self }
    method set-local-weight-function($arg) { $!local-weight-function = $arg; self }
    method set-normalizer-function($arg) { $!normalizer-function = $arg; self }
    method set-w(Math::SparseMatrix:D $arg) { $!W = $arg; self }
    method set-h(Math::SparseMatrix:D $arg) { $!H = $arg; self }
    method set-method($arg) { $!method = $arg; self }
    method set-terms($arg) { @!terms = $arg.Array; self }
    method set-stop-words($arg) { $!stop-words = $arg; self }
    method set-stemming-rules($arg) { $!stemming-rules = $arg; self }
    method set-words-pattern($arg) { $!words-pattern = $arg; self }
    method set-value($arg) { $!value = $arg; self }


    #======================================================
    # Clone
    #======================================================
    method clone() {
        my $obj = ML::LatentSemanticAnalyzer.new;
        $obj.set-documents($!documents) if $!documents.defined;
        $obj.set-document-term-matrix($!doc-term-mat.clone) if $!doc-term-mat.defined;
        $obj.set-weighted-document-term-matrix($!weighted-doc-term-mat.clone) if $!weighted-doc-term-mat.defined;
        $obj.set-w($!W.clone) if $!W.defined;
        $obj.set-h($!H.clone) if $!H.defined;
        $obj.set-terms(@!terms);
        $obj.set-stop-words($!stop-words);
        $obj.set-stemming-rules($!stemming-rules);
        $obj.set-words-pattern($!words-pattern);
        $obj.set-global-term-weights($!global-weights);
        $obj.set-local-weight-function($!local-weight-function);
        $obj.set-normalizer-function($!normalizer-function);
        $obj.set-method($!method);
        $obj.set-value($!value);
        $obj
    }

    #======================================================
    # Generic subs
    #======================================================
    sub left-normalize-matrix-product(Math::SparseMatrix:D $w, Math::SparseMatrix:D $h --> Hash:D) {
        my @d = $w.multiply($w).column-sums.map({ sqrt($_) });
        my @di = @d.map({ .abs > 0 ?? 1 / $_ !! 1 });
        my $s = ML::LatentSemanticAnalyzer::Utilities::diag-matrix(@d, $h.row-names);
        my $si = ML::LatentSemanticAnalyzer::Utilities::diag-matrix(@di, $h.row-names);
        my $W = $w.dot($si);
        $W .= set-column-names($w.column-names);
        return %(:$W, H => $s.dot($h))
    }

    sub right-normalize-matrix-product(Math::SparseMatrix:D $w, Math::SparseMatrix:D $h --> Hash:D) {
        my @d = $h.multiply($h).row-sums.map({ sqrt($_) });
        my @di = @d.map({ .abs > 0 ?? 1 / $_ !! 1 });
        my $s = ML::LatentSemanticAnalyzer::Utilities::diag-matrix(@d, $h.row-names);
        my $si = ML::LatentSemanticAnalyzer::Utilities::diag-matrix(@di, $h.row-names);
        my $W = $w.dot($s);
        $W .= set-column-names($w.column-names);
        return %(:$W, H => $si.dot($h))
    }

    sub row-dictionaries(Math::SparseMatrix:D $mat, Bool:D :$sort = True --> Hash:D) {
        my %rows = $mat.row-names.map({ $_ => {} }).Hash;
        for $mat.tuples(:dataset, :names) -> %rec {
            %rows{%rec<i>}{%rec<j>} = %rec<x>;
        }
        return %rows unless $sort;
        %rows.map(-> $p {
            $p.key => $p.value.sort({ $^b.value <=> $^a.value }).Hash
        }).Hash
    }

    # Five point summary subs
    sub mean(@x) { @x.elems ?? @x.sum / @x.elems !! 0 }
    sub median(@x) {
        given @x.elems {
            when $_ == 0 { 0 }
            when $_ == 1 { @x.head }
            when $_ %% 2 { my @y = @x.sort; (@y[$_ div 2 - 1] + @y[$_ div 2]) / 2 }
            default { my @y = @x.sort; @y[$_ div 2] }
        }
    }
    sub variance(@x) { @x.elems ?? @x.map({ ($_ - mean(@x)) ** 2 }).sum / @x.elems !! 0 }

    #======================================================
    # Main methods
    #======================================================
    #| Make document-term matrix
    method make-document-term-matrix(
            :$docs = Nil,
            :$stop-words = [],
            :$stemming-rules = Nil,
            :$words-pattern = ML::LatentSemanticAnalyzer::Utilities::get-default-word-pattern,
            Int:D :$min-length = 2
            ) {
        my $texts = $docs.defined ?? $docs !! $!documents;
        die 'Cannot find documents.' unless $texts.defined;
        my $mat = document-term-matrix($texts, :$stop-words, :$stemming-rules, :$words-pattern, :$min-length).to-adapted;
        self.set-documents($texts)
        if ML::LatentSemanticAnalyzer::Utilities::is-str-list($texts) || ML::LatentSemanticAnalyzer::Utilities::is-str-hash($texts);
        self.set-document-term-matrix($mat);
        self.set-terms($mat.column-names);
        self.set-stop-words($stop-words);
        self.set-stemming-rules($stemming-rules);
        self.set-words-pattern($words-pattern);
        return self;
    }

    #| Apply LSI functions
    multi method apply-term-weight-functions(
            $global-weight-func = 'IDF',
            $local-weight-func = 'None',
            $normalizer-func = 'Cosine'
                                       ) {
       return self.apply-term-weight-functions(:$global-weight-func, :$local-weight-func, :$normalizer-func);
    }

    #| Apply LSI functions
    multi method apply-term-weight-functions(
            :$global-weight-func = 'IDF',
            :$local-weight-func = 'None',
            :$normalizer-func = 'Cosine'
            ) {
        die 'There is no document-term matrix.' unless $!doc-term-mat ~~ Math::SparseMatrix:D;
        $!weighted-doc-term-mat = self.apply-lsi-weight-functions(
                $!doc-term-mat,
                $global-weight-func,
                $local-weight-func,
                $normalizer-func,
                :native
        );
        $!global-weights = $global-weight-func ~~ Str:D
                ?? self.global-term-function-weights($!doc-term-mat, $global-weight-func).Array
                !! $global-weight-func;
        $!local-weight-function = $local-weight-func;
        $!normalizer-function = $normalizer-func;
        return self;
    }

    #| Extract topics
    method extract-topics(
            :$number-of-topics = 12,
            :$min-number-of-documents-per-term = 12,
            :$method is copy = Whatever,
            :$max-steps = 100) {
        # Process $method
        if $method.isa(Whatever) { $method = 'SVD' }

        die 'There is no weighted document-term matrix.'
        unless self.take-weighted-doc-term-mat;

        # Take terms present in large enough number of documents
        my $smat01 = self.take-doc-term-mat.clone.unitize;
        my %cs = |$smat01.column-sums(:pairs);
        my @ccols = |%cs.grep({ $_.value ≥ $min-number-of-documents-per-term })>>.key.sort;

        # Get matrix
        my $smat = self.take-weighted-doc-term-mat[*;@ccols];

        # The matrix should be adapted.
        # say $smat.core-matrix.WHAT;

        # Extraction
        my ($W, $H);
        given $method {
            when $_ ~~ Str:D && $_.lc ∈ <svd singular-value-decomposition singularvaluedecomposition> {
                my ($s, $v);

                ($W, $s, $v) = $smat.svd($number-of-topics);

                # Scale V with S (in order to get H)
                $H = $s.dot($v.transpose);

                self.set-method('SVD')
            }
            when $_ ~~ Str:D && $_.lc ∈ <nmf nnmf non-negative-matrix-factorization nonnegativematrixfactorization> {
                die 'Topic extraction with Non-Negative Matrix Factorization is not implemented yet.'
            }
            default {
                die 'The value of $method is expected to be "SVD", "NNMF", or Whatever.'
            }
        }

        # Automatic topic names
        my $nd = $number-of-topics.log(10).ceiling + 1;
        my @topic-names = do for ^ $W.columns-count -> $i {
            "tpc." ~ $i.fmt('%0'~"{$nd}d")
        }

        # Automatic topic names re-do using top 3 words per topic
        # TBD

        $W.set-column-names(@topic-names);
        $W.set-row-names($smat.row-names);
        $H.set-row-names(@topic-names);
        $H.set-column-names($smat.column-names);
        self.set-w($W);
        self.set-h($H);

        return self;
    }

    #| Normalize matrix product
    method normalize-matrix-product(Bool:D :$normalize-left = True, Bool:D :$order-by-significance = True) {
        die 'Cannot find matrix factors.' unless $!W ~~ Math::SparseMatrix:D && $!H ~~ Math::SparseMatrix:D;
        my %nres = $normalize-left ?? left-normalize-matrix-product($!W, $!H) !! right-normalize-matrix-product($!W, $!H);
        if $order-by-significance {
            my %factors = $normalize-left
                    ?? %nres<H>.multiply(%nres<H>).row-sums(:pairs)
                    !! %nres<W>.multiply(%nres<W>).column-sums(:pairs);
            my @names = %factors.sort({ $^b.value <=> $^a.value })>>.key;
            %nres<W> = %nres<W>[*; @names];
            %nres<H> = %nres<H>[@names];
        }
        $!W = %nres<W>;
        $!H = %nres<H>;
        self
    }

    #| Derive topics interpretation
    method get-topics-interpretation(Int:D :$number-of-terms = 12, Bool:D :$dataset = False, Bool:D :$wide-form = False, Bool:D :$echo = True, :&echo-function = &say) {
        die 'The argument $number-of-terms is expected to be a positive integer.' unless $number-of-terms > 0;
        die 'Cannot find matrix factors.' unless $!W ~~ Math::SparseMatrix:D && $!H ~~ Math::SparseMatrix:D;
        my %topics = row-dictionaries($!H, :sort).map(-> $p {
            $p.key => $p.value.sort({ $^b.value <=> $^a.value }).head($number-of-terms).Hash
        }).Hash;
        my $res = %topics;
        if $dataset {
            $res = $wide-form
                    ?? %topics.map(-> $p { %(Topic => $p.key, Terms => $p.value.keys.Array) }).sort(*<Topic>).Array
                    !! %topics.map(-> $p { $p.value.kv.map(-> $term, $score { %(Topic => $p.key, Term => $term, Score => $score) }).sort(-*<Score>).Array }).flat(1).Array;
        }
        $!value = $res;
        &echo-function($res) if $echo;
        self
    }

    #| Echo topics table
    method echo-topics-table(|c) { self.echo-topics-interpretation(|c) }

    #| Echo topics interpretation
    method echo-topics-interpretation(Int:D :$number-of-terms = 12, Bool:D :$dataset = True, Bool:D :$wide-form = False, :&echo-function = &say) {
        self.get-topics-interpretation(:$number-of-terms, :$dataset, :$wide-form, :echo, :&echo-function)
    }

    #| Extract statistical thesaurus for given terms
    multi method extract-statistical-thesaurus(@terms, Int:D :$n = 12, Str:D :$method = 'euclidean') {
        die 'Cannot find matrix factors.' unless $!W ~~ Math::SparseMatrix:D && $!H ~~ Math::SparseMatrix:D;
        my %fact-res = left-normalize-matrix-product($!W, $!H);
        my $h = %fact-res<H>;
        my @known = @terms.grep({ $_ ∈ $h.column-names }).sort;
        die 'None of the given words are known.' unless @known;

        my %res;
        if $method.lc eq 'cosine' {
            my $HLocal = Math::SparseMatrix.new(self.take-h.core-matrix.to-csr);
            $HLocal.set-row-names(self.take-h.row-names);
            $HLocal.set-column-names(self.take-h.column-names);

            my $smrObj = ML::SparseMatrixRecommender.new
                    .create-from-matrices(%("Words" => $HLocal.transpose))
                    .apply-term-weight-functions("None", "None","Cosine");

            %res = @known.map({ $_ => $smrObj.recommend([$_, ], $n, :normalize, :!remove-history).take-value.Hash });
            # From similarity to distance
            %res .= map({ my $m = $_.value.values.max; $_.key => $_.value.map({ $_.key => $m - $_.value }).Hash });
        } else {
            for @known -> $word {
                my @target = $h.column-at($word).dense-matrix.map(*[0]);
                my @distances;
                for $h.column-names -> $term {
                    my @vec = $h.column-at($term).dense-matrix.map(*[0]);
                    my $d = sqrt((@target Z- @vec).map(* ** 2).sum);
                    @distances.push($term => $d);
                }
                %res{$word} = @distances.sort(*.value).head($n + 1).Hash;
            }
        }

        $!value = %res;
        self
    }

    #| Extract statistical thesaurus for given terms (all named arguments)
    multi method extract-statistical-thesaurus(:@terms!, Int:D :$n = 12, Str:D :$method = 'euclidean') {
        self.extract-statistical-thesaurus(@terms, :$n, :$method)
    }

    #| Derive statistical thesaurus
    method get-statistical-thesaurus(
            :@terms = $!value,
            Int:D :$number-of-nearest-neighbors = 12,
            Str:D :$method = 'cosine',
            Bool:D :$dataset = True,
            Bool:D :$wide-form = False,
            Bool:D :$echo = True,
            :&echo-function = &say
            ) {
        self.extract-statistical-thesaurus(@terms, n => $number-of-nearest-neighbors, :$method);
        my $res = $!value;
        if $dataset {
            $res = $wide-form
                    ?? $!value.map(-> $p { %(SearchTerm => $p.key, Terms => $p.value.Array.sort(*.value)>>.key.Array) }).sort(*<SearchTerm>).Array
                    !! $!value.map(-> $p { $p.value.kv.map(-> $term, $dist { %(SearchTerm => $p.key, Term => $term, TermDistance => $dist).sort(*<TermDistance>) }) }).flat.Array;
        }
        $!value = $res;
        echo-function($res) if $echo;
        self
    }

    #| Echo statistical thesaurus
    method echo-statistical-thesaurus(|c) {
        self.get-statistical-thesaurus(|c, :echo)
    }

    #| Represent a query by LSA object's terms
    method represent-by-terms($query, Bool:D :$apply-lsi-functions = True) {
        die 'Cannot find document-term matrix.' unless $!doc-term-mat ~~ Math::SparseMatrix:D || $!weighted-doc-term-mat ~~ Math::SparseMatrix:D;
        given $query {
            when Str:D {
                return self.represent-by-terms([$_], :$apply-lsi-functions);
            }
            when Positional:D {
                my $qmat = ML::LatentSemanticAnalyzer.new
                        .make-document-term-matrix(
                                docs => $_,
                                stop-words => $!stop-words,
                                stemming-rules => $!stemming-rules,
                                words-pattern => $!words-pattern
                        )
                        .take-doc-term-mat;
                return self.represent-by-terms($qmat, :$apply-lsi-functions);
            }
            when Math::SparseMatrix:D {
                my @columns = $!doc-term-mat.defined ?? $!doc-term-mat.column-names !! $!weighted-doc-term-mat.column-names;
                my $qmat = $_.impose-column-names(@columns);
                die 'The obtained query matrix has no entries.' if $qmat.explicit-length == 0;
                if $apply-lsi-functions {
                    die 'Global, local, and normalizer weight functions must be available.'
                            unless $!global-weights.defined && $!local-weight-function.defined && $!normalizer-function.defined;
                    $qmat = self.apply-lsi-weight-functions($qmat, $!global-weights, $!local-weight-function, $!normalizer-function);
                }
                $!value = $qmat;
            }
            default {
                die 'Unknown type of the argument query.';
            }
        }
        self
    }

    #| Represent a query by LSA object's topics
    method represent-by-topics($query, Bool:D :$apply-lsi-functions = True, Str:D :$method = 'algebraic') {
        die 'Cannot find matrix factors.' unless $!W ~~ Math::SparseMatrix:D && $!H ~~ Math::SparseMatrix:D;
        die 'The argument method is expected to be algebraic or recommendation.'
                unless $method.lc ∈ <algebraic recommendation>;
        my $qmat = self.represent-by-terms($query, :$apply-lsi-functions).take-value;
        $qmat = $qmat.impose-column-names($!H.column-names);
        die 'The obtained query matrix has no entries.' if $qmat.explicit-length == 0;
        self.normalize-matrix-product(:!normalize-left);
        $!value = $qmat.dot($!H.transpose);
        self
    }

    #| Echo document-term matrix statistics
    method echo-document-term-matrix-statistics(Real :$log-base = 0) {
        die 'There is no document-term matrix.' unless $!doc-term-mat ~~ Math::SparseMatrix:D;
        say 'Document-term matrix:';
        say $!doc-term-mat.gist;

        my @row-counts = $!doc-term-mat.unitize.row-sums;
        my @col-counts = $!doc-term-mat.unitize.column-sums;
        if $log-base > 0 {
            @row-counts = @row-counts.map({ $_ > 0 ?? log($_, $log-base) !! 0 });
            @col-counts = @col-counts.map({ $_ > 0 ?? log($_, $log-base) !! 0 });
        }
        for 'Number of terms per document' => @row-counts, 'Number of documents per term' => @col-counts -> $p {
            my @x = $p.value;
            say "{$p.key}:";
            say "\tmin:     {@x.min // 0}";
            say "\tmean:    {mean(@x)}";
            say "\tmedian:  {median(@x)}";
            say "\tmax:     {@x.max // 0}";
            say "\tstd:     {sqrt(variance(@x))}";
        }
        self
    }

    #| Represent as hashmap
    method Hash(::?CLASS:D: --> Hash:D) {
        %(
                matrices => %(doc-term-mat => $!doc-term-mat, weighted-doc-term-mat => $!weighted-doc-term-mat),
                W => $!W,
                H => $!H,
                stemming-rules => $!stemming-rules,
                stop-words => $!stop-words,
                global-weights => $!global-weights,
                local-weight-function => $!local-weight-function,
                normalizer-function => $!normalizer-function,
                method => $!method,
                value => $!value
        )
    }

    #| Gist
    multi method gist(::?CLASS:D: --> Str) {
        if $!doc-term-mat ~~ Math::SparseMatrix:D {
            "LatentSemanticAnalyzer object with {$!doc-term-mat.rows-count} documents and {$!doc-term-mat.columns-count} terms."
        } elsif $!weighted-doc-term-mat ~~ Math::SparseMatrix:D {
            "LatentSemanticAnalyzer object with {$!weighted-doc-term-mat.rows-count} documents and {$!weighted-doc-term-mat.columns-count} terms."
        } else {
            'LatentSemanticAnalyzer object.'
        }
    }
}