<?
header('Content-type: application/json');

function mmmlog($message){
  $log = fopen('mmm.log', 'a');
  fwrite($log, date('r'));
  fwrite($log, ' ');
  fwrite($log, $_SERVER['REMOTE_ADDR']);
  fwrite($log, ' ');
  fwrite($log, $message);
  fwrite($log, "\n");
  fclose($log);
}

echo('{"error":"You are using a broken version of MegaMegaMonitor. Please upgrade to v106 or higher."}');
die();

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
$stmt->execute(array($username));
if($row = $stmt->fetch(PDO::FETCH_ASSOC)){
  $user_id = $row['id'];
} else {
  mmmlog($username . " not found");
  echo('{"error":"Your username was not found in any participating subreddit. You must be a member of a participating subreddit in order to use MegaMegaMonitor. Sometimes MegaMegaMonitor can be slow to update, so if you\'ve only just been invited into a participating subreddit, try again in 24 hours. If you\'re still having trouble, contact /u/avapoet"}');
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

if(file_exists('output/'.$filename.'.json')){
  mmmlog($username . " requested " . $filename);
  readfile('output/'.$filename.'.json');
} else {
  mmmlog($username . " needed file " . $filename . " but it was not found.");
  echo('{"error":"The JSON file you needed could not be generated. If this problem persists, contact /u/avapoet, citing error MM3:' + $filename + '."}');
}
die();
?>