#!/usr/bin/env perl
use strict; # ограничить применение небезопасных конструкций
use warnings; # выводить подробные предупреждения компилятора
use diagnostics; # выводить подробную диагностику ошибок
use LWP::UserAgent;
require HTTP::Response;
use HTML::TreeBuilder;
use Getopt::Std;
#Debian: liblwp-protocol-socks-perl
use LWP::Protocol::socks;

package main;

my $thmax = 30; #MAX THREAD COUNT

binmode(STDOUT, ":utf8");
$SIG{INT} = \&stop_and_print; # ссылка на подпрограмму

#threads to div block "main"
sub parser($){ my $ref2threads = $_[0];
    my @threadsres;
    foreach my $el (@$ref2threads){
	my $elr = $el->look_down("class", "messageroot");
	#img
	my $aimg = $elr->look_down("class", "image_link");
	my $imgres = $aimg->as_HTML;
	if($imgres =~ m%img/nope.png|img/invalid.png% ){
	    $imgres = '';
	}
	#img
	my $topic = $elr->look_down("class", "topicline");
	my $b = $topic->look_down('_tag', 'b');
	#	my $fright = $b->right();
	my $message;                       #first line of toppic if subject is None
	if ($b->as_text eq 'None'){
	    $b->delete();
	    $message = substr($elr->look_down("class", "message_span")->as_text, 0,55);
	}else{ $message = ''; }
	my $topicres = $topic->as_HTML;
	push @threadsres, "<div>".$imgres.$topicres.$message."</div>";
    }
    my $res = join ('', @threadsres);
    return '<div id="main">'.$res.'</div>';
}

die "-h for hiddenchan.i2p or -4 for 404chan.i2p\n" unless ($ARGV[0]);
die "board name please\n" unless ($ARGV[1]);
my $firstpar = shift; # первый параметр: -h или -4 или -f
my $razd = shift; # имя раздела, параметр коммандной строки

my $ua = LWP::UserAgent->new; #параметры подключения
$ua->agent("Mozilla/5.0 (Windows NT 5.1; rv:5.0.1) Gecko/20100101 Firefox/5.0.1");
#$ua->proxy(['http'], "http://127.0.0.1:4446");
my $urlbase;
if ($firstpar eq '-h'){
    $urlbase = "http://hiddenchan.i2p/";
    $ua->proxy(['http'], "http://127.0.0.1:4446"); #i2p
}elsif($firstpar eq '-4'){
    $urlbase = "http://404chan.i2p/";
    $ua->proxy(['http'], "http://127.0.0.1:4446"); #i2p
}elsif($firstpar eq '-f'){
    $urlbase = "http://lp4t52xp5vlhyhkb.onion/";
    $ua->proxy([qw(http https)] => "socks://172.16.0.1:9150"); #tor
}else{ die "wrong first parameter. you need -h or -4 or -f"; }

my $url = $urlbase.$razd."-1.html"; #ссылка на первую страницу раздела

my $req = HTTP::Request->new(GET => $url);
my $res;
for(my $i = 1; $i < 7; $i++){ #цикл запросов первой страницы раздела
    $res = $ua->request($req);
    last if ($res->is_success);
    print (($res->status_line)." Let\'s try again...\n");
}
die "No connection".($res->status_line)."\n" unless $res->is_success;

my $tree = HTML::TreeBuilder->new; # обрабатываем первую страницу в дерево
$tree->ignore_ignorable_whitespace(0);
$tree->store_comments(0);
#    print $res->decoded_content;
$tree->parse($res->decoded_content);
$tree->eof();

my $divel=$tree->look_down("class", "pagelist"); #страниц в разделе
my @num = $divel->as_HTML =~ m/\[[0-9]+\]/ig; 
my $pages = substr(pop @num,1,-1); #получили количество страниц
$pages = ($pages > $thmax) ? $thmax : $pages;
#$tree->dump;

my @threads1 = $tree->look_down("class", "thread");
my @weba; #собиратель готовых к печати вставок
push @weba, parser(\@threads1);

$tree = $tree->delete; #удаляем дерево первой страницы

for(my $i = 2; $i <= $pages; $i++){ # делаем то же самое с остольными страницами
    my $url = $urlbase.$razd."-".$i.".html"; #ссылка на первую страницу раздела

    my $req = HTTP::Request->new(GET => $url);
    my $res;
    for(my $i = 1; $i < 7; $i++){ #цикл запросов
	$res = $ua->request($req);
	last if ($res->is_success);
	print "one more time\n";
    }
    if($res->is_success){
	print "well done ".$url."\n";
    }else{
	print "No connection".($res->status_line)." for ".$url."\n over";
	last;
    }

    my $tree = HTML::TreeBuilder->new; # обрабатываем первую страницу в дерево
    $tree->ignore_ignorable_whitespace(0);
    $tree->store_comments(0);
    $tree->parse($res->decoded_content);
    $tree->eof();

    my @threads = $tree->look_down("class", "thread");
    push @weba, parser(\@threads);
    $tree = $tree->delete;
}


&stop_and_print;

#Finish here.











#function
#       Print what we got
sub stop_and_print {
    if (@weba){
	
	my $webins = join ('', @weba); #собираем все строки из массива в строку

	#$divel->dump;
	#    print($tree->content_list());
	#    print "ref=". ref($res->content);


	my $web_page = <<HTML_OUT; # html с названиями тредов и картинками
<!DOCTYPE html>
    <html>
    <head>
    <title>$razd</title>
    <base href="$urlbase" target="_blank">
    <style>
    *{
      margin: 0px;
      padding: 0px;
}
	html, body{
	  height: 100%;
	}
	body{
	    background-color: #ccc;
	}

	div {
	  margin:1px;
	    text-align: center;
	}
	#main{
      margin:2px;
      border: 1px solid #fff; 
        height: 216px : initial;
      overflow: hidden;
    }
    #main>div{
  width:-moz-min-content;
  height:auto;
  display: inline-block;
}
</style>
    <script>
    $(document).ready(function(){
});
</script>
    </head>
    <body>
    <!--
    <div id="main">
    <div>1</div>
    <div>2</div>
    <div>3</div>
    </div>
    -->
    $webins

    </body>
    </html>
HTML_OUT

     open FILE, ">", "pover4-".$firstpar."-".$razd.".html" or die $!;
     binmode(FILE, ":utf8");
     print FILE $web_page;
     close FILE;

     print "pover4-".$firstpar."-".$razd.".html","\n";
  }
  exit;    
}

__END__
