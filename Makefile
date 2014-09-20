update:
	ssh irc 'cd /home/frew/code/corn && \
		git pull && \
		env SVDIR=/home/frew/local-services sv restart corn'
