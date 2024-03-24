#!/usr/bin/env python3

# pyright: strict

import urllib.parse
from dataclasses import dataclass
from datetime import datetime, timedelta
from sys import exit
from typing import Optional
from urllib.request import urlopen
from xml.dom.minidom import Element, parse


PREFS_PATH = '/config/Library/Application Support/Plex Media Server/Preferences.xml'
STATE_FILE = '/var/run/dvr_healthcheck.state'


@dataclass
class Operation:
    title: str
    status: str
    start: datetime
    duration: Optional[timedelta]
    end: Optional[datetime]

    @classmethod
    def from_mediagraboperation(cls, el: Element):
        video = el.getElementsByTagName('Video')[0]
        start = datetime.fromisoformat(video.getAttribute('originallyAvailableAt'))
        duration_str = video.getAttribute('duration')
        if duration_str:
            duration = timedelta(milliseconds=int(video.getAttribute('duration')))
            end = start + duration
        else:
            duration = None
            end = None
        
        return cls(
            title=video.getAttribute('grandparentTitle'),
            status=el.getAttribute('status'), 
            duration=duration, 
            start=start, 
            end=end
        )


def get_plex_token():
    prefs = parse(PREFS_PATH)
    prefs_node = prefs.getElementsByTagName('Preferences')[0]
    return prefs_node.getAttribute('PlexOnlineToken')

def get_scheduled(plex_token: str):
    token = urllib.parse.quote(plex_token)
    url = f'http://localhost:32400/media/subscriptions/scheduled?X-Plex-Token={token}'
    with urlopen(url) as response:
        doc = parse(response)
        root = doc.getElementsByTagName('MediaContainer')[0]
        return [ 
            Operation.from_mediagraboperation(el) 
            for el in root.getElementsByTagName('MediaGrabOperation') 
        ]
    

plex_token = get_plex_token()

scheduled = get_scheduled(plex_token)

for op in reversed(sorted(scheduled, key=lambda op: op.start)):

    # Check for stuck
    if op.status == 'inprogress' and op.end and op.duration:
        if datetime.now() > (op.end + op.duration):
            print(f'Stuck recording: {op.title}')
            exit(1)

    # TODO check for failed
    # status == 'error'
