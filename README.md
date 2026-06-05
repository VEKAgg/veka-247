# 247Live - 24/7 Automated Live Streaming Playout

## Quick Start
```bash
sudo systemctl start playout
sudo journalctl -fu playout
Adding Clips
Drop .mp4/.mkv/.mov files into the 247Live dataset on TrueNAS.
Updating Keys
sudo bash -c 'echo -n "NEW_KEY" > /etc/credstore/yt_key'
sudo bash -c 'echo -n "NEW_KEY" > /etc/credstore/tw_key'
sudo bash -c 'echo -n "NEW_KEY" > /etc/credstore/kick_key'
sudo chmod 600 /etc/credstore/*
sudo systemctl restart playout
