use v6.d;

use Math::SparseMatrix;

unit module ML::LatentSemanticAnalyzer::Utilities;

my constant $DEFAULT-WORDS-PATTERN = rx/ <[\w']>+ | <[.,!?;]> /;

our sub get-default-word-pattern() { $DEFAULT-WORDS-PATTERN }

my @ENGLISH-STOP-WORDS = <
        a about above after again against all am an and any are as at be because been before being below between
        both but by can did do does doing down during each few for from further had has have having he her here hers
        herself him himself his how i if in into is it its itself just me more most my myself no nor not now of off on
        once only or other our ours ourselves out over own same she should so some such than that the their theirs
        them themselves then there these they this those through to too under until up very was we were what when
        where which while who whom why will with you your yours yourself yourselves
>;

our sub get-english-stop-words() { @ENGLISH-STOP-WORDS }

#==========================================================
# Data retrieval
#==========================================================

#| Get a dataset with conference abstracts. Returns an array of hashmaps.
our sub get-abstracts-dataset() {
    my $fileResource = %?RESOURCES<dfAbstracts.csv>;

    my @lines = slurp($fileResource).lines;
    my @keys = @lines.head.subst('"', :g).split(',', :skip-empty).Array;
    my @tbl = do for @lines.tail(*-1).grep(*) -> $line {
        (@keys Z=> $line.subst(/ ^ '"' | '"' $/, :g).split('","', :skip-empty).Array).Hash
    }
    return @tbl;
}
#= Ingests the resource file "dfAbstracts.csv" of ML::LatentSemanticAnalyzer.

#==========================================================
# Predidcates
#==========================================================

# TODO: Refactor using "Data::TypeSystem".

our sub is-str-list($x --> Bool) {
    $x ~~ Iterable:D && $x !~~ Associative:D && $x !~~ Str:D && $x.list.all ~~ Str:D
}

our sub is-list-of-str-lists($x --> Bool) {
    $x ~~ Iterable:D && $x !~~ Associative:D && $x !~~ Str:D
            && $x.list.all ~~ Iterable:D
            && $x.list.all.list.all ~~ Str:D
}

our sub is-str-hash($x --> Bool) {
    $x ~~ Associative:D && $x.keys.all ~~ Str:D && $x.values.all ~~ Str:D
}

our sub is-hash-of-str-lists($x --> Bool) {
    $x ~~ Associative:D
            && $x.keys.all ~~ Str:D
            && $x.values.all ~~ Iterable:D
            && $x.values.all.list.all ~~ Str:D
}

#==========================================================
# Word processing
#==========================================================

our sub stop-words-set($stop-words) {
    given $stop-words {
        when Bool:D { $_ ?? SetHash.new(@ENGLISH-STOP-WORDS) !! SetHash.new }
        when Positional:D { SetHash.new($_.Array) }
        when Set:D | SetHash:D { $_ }
        when Any { SetHash.new }
        default { die 'The argument stop-words is expected to be a Boolean, a list, a set, or Nil.' }
    }
}

our sub stem-word(Str:D $word, $stemming-rules --> Str) {
    given $stemming-rules {
        when Bool:D {
            return $word unless $_;
            # Lightweight fallback. Full Porter stemming is intentionally not
            # implemented here; callers can pass a Callable for exact stemming.
            return $word.subst(/ 'ies' $/, 'y')
                    .subst(/ 'ing' $/, '')
                    .subst(/ 'ed' $/, '')
                    .subst(/ 's' $/, '');
        }
        when Callable:D { $_($word).Str }
        when Associative:D { $_{$word}:exists ?? $_{$word}.Str !! $word }
        when Any { $word }
        default { die 'The argument stemming-rules is expected to be a Boolean, Callable, Hash, or Nil.' }
    }
}

our sub diag-matrix(@values, @names --> Math::SparseMatrix:D) {
    my @rules = @values.kv.map(-> $i, $v { ($i, $i) => $v });
    Math::SparseMatrix.new(rules => @rules, nrow => @values.elems, ncol => @values.elems, row-names => @names, column-names => @names).to-adapted
}

#| Tokenize text with a given pattern matching.
our sub tokenize(Str:D $text, $words-pattern = Whatever) {
    if $words-pattern ~~ Regex:D {
        return $text.comb($words-pattern)>>.Str;
    }
    if $words-pattern.isa(Whatever) || $words-pattern ~~ Str:D {
        return $text.comb($DEFAULT-WORDS-PATTERN)>>.Str;
    }
    die 'The argument words-pattern is expected to be a Regex, a string, or Whatever.';
}

#| Convert a string or a list of strings into bags of words.
our sub to-bag-of-words(
        $docs,
        :$stop-words = [],
        :$stemming-rules = Nil,
        :$words-pattern = $DEFAULT-WORDS-PATTERN,
        Int:D :$min-length = 2
                        ) is export {
    if $docs ~~ Str:D {
        return to-bag-of-words([$docs], :$stop-words, :$stemming-rules, :$words-pattern, :$min-length);
    }

    my @documents = $docs.Array;
    die 'The first argument is expected to be a string or a list of strings.'
    unless @documents.all ~~ Str:D;

    my $stop-set = stop-words-set($stop-words);
    my @bags;
    for @documents -> $doc {
        my @terms = tokenize($doc.lc, $words-pattern)
                .grep({ $min-length <= 0 || .chars >= $min-length })
                .grep({ $_ ∉ $stop-set })
                .map({ stem-word($_, $stemming-rules) })
                .grep(*.chars > 0)
                .Array;
        @bags.push(@terms);
    }
    @bags
}

#| Construct a document-term matrix from documents or already tokenized documents.
our sub document-term-matrix(
        $docs,
        :$stop-words = [],
        :$stemming-rules = Nil,
        :$words-pattern = $DEFAULT-WORDS-PATTERN,
        Int:D :$min-length = 2
        --> Math::SparseMatrix:D
                             ) is export {
    my @ids;
    my @doc-terms;

    if is-str-list($docs) {
        @ids = (^$docs.elems).map({ "id.$_" }).Array;
        @doc-terms = to-bag-of-words($docs, :$stop-words, :$stemming-rules, :$words-pattern, :$min-length);
    } elsif is-list-of-str-lists($docs) {
        @ids = (^$docs.elems).map({ "id.$_" }).Array;
        @doc-terms = $docs.Array;
    } elsif is-str-hash($docs) {
        @ids = $docs.keys.sort.Array;
        @doc-terms = to-bag-of-words(@ids.map({ $docs{$_} }).Array, :$stop-words, :$stemming-rules, :$words-pattern, :$min-length);
    } elsif is-hash-of-str-lists($docs) {
        @ids = $docs.keys.sort.Array;
        @doc-terms = @ids.map({ $docs{$_}.Array }).Array;
    } else {
        die 'The first argument is expected to be a list of strings, hash of strings, list of term lists, or hash of term lists.';
    }

    my @terms = @doc-terms.map(*.Slip).unique.sort.Array;
    my %term-index = @terms Z=> ^@terms.elems;

    my @rules;
    for @doc-terms.kv -> $i, @terms-in-doc {
        my %counts;
        %counts{$_}++ for @terms-in-doc;
        @rules.append: %counts.kv.map(-> $term, $count { ($i, %term-index{$term}) => $count });
    }

    Math::SparseMatrix.new(
            rules => @rules,
            nrow => @ids.elems,
            ncol => @terms.elems,
            row-names => @ids,
            column-names => @terms
            )
}