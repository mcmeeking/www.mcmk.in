#!/bin/bash

echo "$( date -Iseconds ): Starting site update."

cd /home/ubuntu/hugo || ( 
	
	echo "$( date -Iseconds ): Failed to open site directory. Bailing out"
	
	exit 1

)

/usr/bin/sudo -u ubuntu git fetch

if ! /usr/bin/sudo -u ubuntu git diff origin/master --quiet ; then

	echo "$( date -Iseconds ): Changes detected upstream, pulling now."

	/usr/bin/sudo -u ubuntu git merge

    echo "$( date -Iseconds ): Initialising submodules."

    /usr/bin/sudo -u ubuntu git submodule update --init --recursive 

	echo "$( date -Iseconds ): Testing build."
	
	if ! /usr/bin/sudo -u ubuntu /usr/local/bin/hugo ; then

		echo "$( date -Iseconds ): Build failed, reverting."

		/usr/bin/sudo -u ubuntu git reset --hard master@{1}

		echo "$( date -Iseconds ): Exiting."

		exit 50

	fi

	echo "$( date -Iseconds ): Build succeeded, testing NGINX."

	if ! /usr/sbin/nginx -t ; then

		echo "$( date -Iseconds ): NGINX test failed, reverting."

		/usr/bin/sudo -u ubuntu git reset --hard master@{1}

        echo "$( date -Iseconds ): Exiting."

        exit 51

	fi

	echo "$( date -Iseconds ): NGINX self-test passed, checking service is running."

	if ! /bin/systemctl is-active --quiet nginx ; then

		echo "$( date -Iseconds ): Service not running, exiting without reload."

		exit 2

	fi

	echo "$( date -Iseconds ): All tests passed, publishing site."

	/usr/sbin/service nginx restart || ( 
		
		echo "$( date -Iseconds ): FINAL RESTART FAILED, ATTEMPTING TO REVERT"

		/usr/bin/sudo -u ubuntu git reset --hard master@{1}

		/usr/sbin/service nginx restart || exit 100

	)

	echo "$( date -Iseconds ): Site reloaded successfully. Changes are now live."

fi