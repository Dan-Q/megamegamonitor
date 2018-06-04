<?
header('Content-type: application/json');

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
  mmmlog($username . " was an invalid username");
  echo('{"error":"Your Reddit username does not appear to be valid. If you think this is a mistake, contact /u/avapoet."}');
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
  mmmlog($username . " not found");
  echo('{"error":"Your username was not found in any participating subreddit. You must be a member of a participating subreddit in order to use MegaMegaMonitor. Sometimes MegaMegaMonitor can be slow to update, so if you\'ve only just been invited into a participating subreddit, try again in 24 hours. If you\'re still having trouble, contact /u/avapoet"}');
  die();
}

// verify identity
$accesskey = $_REQUEST['accesskey'];
$accesskey = ($accesskey === null) ? '' : $accesskey;
$stmt = $conn->prepare('SELECT COUNT(id) FROM accesskeys WHERE user_id = ? AND secret_key = ?;');
if(!$stmt->execute(array($user_id, $accesskey))) die($stmt->errorInfo()[2]);
$row = $stmt->fetch();
if($row[0] == 0){
  // unproven or invalid identity - work out how we're going to ask them to prove it!
  $stmt = $conn->prepare('SELECT display_name, access_secret FROM subreddits WHERE id IN (SELECT subreddit_id FROM contributors WHERE user_id = ?) ORDER BY chain_number DESC, spriteset_position DESC, id DESC LIMIT 1');
  if(!$stmt->execute(array($user_id))) die($stmt->errorInfo()[2]);
  if($row = $stmt->fetch()){
    $proof = $_REQUEST['proof'];
    if($proof != '') { // PROOF-CHECKING CODE REMOVED IN THIS COPY; WRITE YOUR OWN, SORRY
      // valid proof provided; set up an accesskey
      mmmlog($username . " provided proof of identity");
      $key = sha1($username.'mmm'.uniqid('mmm-', true).date());
      $stmt = $conn->prepare('INSERT INTO accesskeys(user_id, secret_key, created_at, updated_at) VALUES(?, ?, NOW(), NOW())');
      if(!$stmt->execute(array($user_id, $key))) die($stmt->errorInfo()[2]);
      echo('{"accesskey":"'.$key.'"}');
    } else {
      mmmlog($username . " needs to prove access to ".$row['display_name']);
      echo('{"proof":"'.$row['display_name'].'"}');
    }
  } else {
    mmmlog($username . " no possible proofs");
    echo('{"error":"No possible ways were found for your Reddit account to prove its identity. This is probably a bug. Contact /u/avapoet for help."}');
  }
  die();
}

// touch the installation_seen_at datetime
$stmt = $conn->prepare('UPDATE users SET installation_seen_at = NOW() WHERE id = ?;');
$stmt->execute(array($user_id));
// get the list of subreddits
$stmt = $conn->prepare('SELECT subreddits.display_name FROM contributors LEFT JOIN subreddits ON contributors.subreddit_id = subreddits.id WHERE contributors.user_id = ? AND subreddits.spriteset_position IS NOT NULL ORDER BY subreddits.display_name;');
$stmt->execute(array($user_id));
$rows = array_map('strtolower', $stmt->fetchAll(PDO::FETCH_COLUMN));
$filename = md5(strtolower(implode('-', $rows)));

if(file_exists('output2/'.$filename.'.json')){
  mmmlog($username . " requested " . $filename);
  readfile('output2/'.$filename.'.json');
} else {
  mmmlog($username . " needed file " . $filename . " but it was not found.");
  echo('{"error":"The JSON file you needed could not be generated. If this problem persists, contact /u/avapoet, citing error MM3:' + $filename + '."}');
}
die();
?>