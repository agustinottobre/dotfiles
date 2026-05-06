#!/bin/bash                                                                                                                                                                                    
# This hooks script syncs task warrior to the configured task server.
# The on-exit event is triggered once, after all processing is complete.

# Make sure hooks are enabled

TASK_DIR=$HOME/.task
LOCK_FILE=$TASK_DIR/autosync.lock

if [ ! -f $LOCK_FILE ]; then
  touch $LOCK_FILE

  # Only sync, if the backlog is not empty
  if ((`cat $TASK_DIR/backlog.data | wc -l` > 1)); then
    # rc.hooks=0 disables hooks, preventing a loop
    #add $(date +'%Y%m%dT%H%M') to entries?
    task rc.hooks=0 sync >> $TASK_DIR/sync_hook.log 
  fi  

  rm $LOCK_FILE
fi

exit 0
