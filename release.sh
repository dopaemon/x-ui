#!/bin/bash
gh release show $VERSIONS > /dev/null 2>&16	# > /dev/null 2>&16 is to hide the error message
if [ $? -eq 0 ]; then
	gh release delete $VERSIONS -y
fi