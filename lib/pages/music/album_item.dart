class AlbumItem {
  final String title;
  final String coverUrl;
  final String spotifyUrl;
  final String appleMusicUrl;
  final String soundCloudUrl; 
  final String youtubeUrl;
  final bool soundCloudOnly;    
  final String lyrics;        
  final List<String> tracks;
  final String audioPath;
  final bool isLocked;

  const AlbumItem({
    required this.title,
    required this.coverUrl,
    required this.spotifyUrl,
    required this.appleMusicUrl,
    required this.soundCloudUrl,
    required this.youtubeUrl,
    required this.lyrics,
    required this.soundCloudOnly,
    required this.tracks,
    required this.audioPath,
    this.isLocked = false,
  });
}
