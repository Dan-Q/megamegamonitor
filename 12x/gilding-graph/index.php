<?
  $username = $_POST['u'];
  if(!preg_match('/^[a-zA-Z0-9_-]{3,}$/', $username)){
    ?>
      <h1>Gilding Grapher from MegaMegaMonitor</h1>
      <p>How to use:</p>
      <ol>
        <li>Use a good browser. Firefox, Chrome, Opera, any <em>very</em>-recent version of Internet Explorer, etc.</li>
        <li>
          Drag this link to your Bookmarks/Favorites:
          <a href="javascript:(function(){function l(n,i){var t=%22/u/%22+n+%22/gilded/given.json?limit=100&after=%22+i;$(%22#d%22).append(%22.%22),$.getJSON(t,function(i){if(my_gildings_given_json.push(i.data.children),null!==i.data.after)setTimeout(function(){l(n,i.data.after)},2e3);else{for(var t=[];my_gildings_given_json.length>0;)t=t.concat(my_gildings_given_json.shift());t=JSON.stringify(t.map(function(n){return{kind:n.kind,subreddit:n.data.subreddit,author:n.data.author}})),$(%22body%22).html('<h1>Almost done...</h1><p>Just drawing some graphs...</p><form method=%22post%22 action=%22https://danq.me/megamegamonitor/gilding-graph/%22><input type=%22hidden%22 name=%22u%22 /><input type=%22hidden%22 name=%22g%22 /></form>'),$('input[name=%22u%22]').val(n),$('input[name=%22g%22]').val(t),$(%22form%22).submit()}})}var my_gildings_given_json=[];$(%22body%22).html('<h1>Please wait<span id=%22d%22></span></h1><p>This will take a little over 2 seconds per 100 gildings you\'ve given.</p>'),$.get(%22/api/me.json%22,function(n){l(n.data.name,%22%22)});})();" style="font-weight: bold;">
            Graph My Gilding
          </a>
          (or right click it and add it to your bookmarks/favorites)
        </li>
        <li>Go to <a href="https://www.reddit.com/">Reddit</a>.</li>
        <li>Click the bookmark.</li>
      </ol>
    <?
    die();
  }
  $json = json_encode(json_decode($_POST['g']));

  $json = str_ireplace(array('CENSORED MEGALOUNGE NAME',
                             'CENSORED MEGALOUNGE NAME',
                             'CENSORED MEGALOUNGE NAME',
                             'CENSORED MEGALOUNGE NAME',
                             'CENSORED MEGALOUNGE NAME',
                             'CENSORED MEGALOUNGE NAME',
                             'CENSORED MEGALOUNGE NAME',
                             'CENSORED MEGALOUNGE NAME',
                             'CENSORED MEGALOUNGE NAME',
                             'CENSORED MEGALOUNGE NAME',
                             'CENSORED MEGALOUNGE NAME',
                             'CENSORED MEGALOUNGE NAME'
                            ),
                       array('the secret MegaLounge',
                             'x28-gilded MegaLounge',
                             'x29-gilded MegaLounge',
                             'x30-gilded MegaLounge',
                             'x31-gilded MegaLounge',
                             'x32-gilded MegaLounge',
                             'x33-gilded MegaLounge',
                             'x34-gilded MegaLounge',
                             'x35-gilded MegaLounge',
                             'x36-gilded MegaLounge',
                             'x37-gilded MegaLounge',
                             'x38-gilded MegaLounge'
                            ),
                       $json);

  $filename = 'output/'.$username.'-'.date('YmdHis').'-'.substr(md5('s89n4s3'.$username.date('YmdHis')), 0, 8).'.html';

  $output = file_get_contents('template.html');
  $output = str_replace('{{username}}', $username, $output);
  $output = str_replace('{{json}}', $json, $output);
  file_put_contents($filename, $output);
  header('Location: '.$filename);
?>