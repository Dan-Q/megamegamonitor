<?
header('Content-type: text/plain');

function mmmlog($message){
  if($_SERVER["HTTP_X_FORWARDED_FOR"] != ""){
    $ip = $_SERVER["HTTP_X_FORWARDED_FOR"];
  }else{
    $ip = $_SERVER["REMOTE_ADDR"];
  }
  $log = fopen('mmm2.log', 'a');
  fwrite($log, date('r'));
  fwrite($log, ' ');
  fwrite($log, $ip);
  fwrite($log, ' ');
  fwrite($log, $message);
  fwrite($log, "\n");
  fclose($log);
}

// determine username
$username = $_REQUEST['username'];

if(!preg_match('/^[a-zA-Z0-9_-]{3,}$/', $username)) {
  mmmlog("NinjaPirateVisible: " . $username . " was an invalid username");
  echo("Your Reddit username does not appear to be valid. If you think this is a mistake, contact /u/avapoet.");
  die();
}

// connect to DB to suss out which subs we're in and get right pre-prepped JSON
$conn = new PDO('mysql:host=localhost;dbname=megamegamonitor', 'mmm', 'DATABASE PASSWORD');
// find the user
$stmt = $conn->prepare('SELECT id FROM users WHERE display_name = ? LIMIT 1;');
if(!$stmt->execute(array($username))) die($stmt->errorInfo()[2]);
if($row = $stmt->fetch()){
  $user_id = $row['id'];
} else {
  mmmlog("NinjaPirateVisible: " . $username . " not found");
  echo("Your username was not found in any participating subreddit. You must be a member of a participating subreddit in order to use MegaMegaMonitor. Sometimes MegaMegaMonitor can be slow to update, so if you\'ve only just been invited into a participating subreddit, try again in 24 hours. If you\'re still having trouble, contact /u/avapoet");
  die();
}

// verify identity
$accesskey = $_REQUEST['accesskey'];
$accesskey = ($accesskey === null) ? '' : $accesskey;
$stmt = $conn->prepare('SELECT COUNT(id) FROM accesskeys WHERE user_id = ? AND secret_key = ?;');
if(!$stmt->execute(array($user_id, $accesskey))) die($stmt->errorInfo()[2]);
$row = $stmt->fetch();
if($row[0] == 0){
  // unproven or invalid identity - disallow until proven the normal way
  echo("Identity verification failed. Is MegaMegaMonitor working normally for you? I can't see how it would be! - /u/avapoet");
  die();
}

// touch the installation_seen_at datetime and get/update the requested variable
if(isset($_REQUEST['v'])) {
  $stmt = $conn->prepare('UPDATE users SET installation_seen_at = NOW(), ninja_pirate_visible = ? WHERE id = ?;');
  $stmt->execute(array(($_REQUEST['v'] == '1' ? 1 : 0), $user_id));
  mmmlog("NinjaPirateVisible: " . $username . " requested " . ($_REQUEST['v'] == '1' ? 'visible' : 'hidden'));
  echo("Your change has been processed. It may take up to 24 hours before it can be seen by other people.");
} else {
  $stmt = $conn->prepare('SELECT ninja_pirate_visible FROM users WHERE id = ?;');
  $stmt->execute(array($user_id));
  $row = $stmt->fetch();
  echo($row[0]);
}
die();
?>