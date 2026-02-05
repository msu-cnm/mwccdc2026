## Permissions

- Displaying user and group info
  - user: `cat /etc/passwd` displays users & privs
  - group: `cat /etc/group` displays all groups
- Deleting users and groups
  - `userdel -rf <username>`
  - `groupdel <groupname>`
- Adding users and groups
  - `groupadd <newGroupName>`
  - `useradd <userName>`
- Adding & Removing Users To Groups
  - `usermod -a -G <groupName> <userName>` - add
  - `deluser <user> <group>` - remove
- View Groups a User is In
  - `groups <userName>`
- View what users are in a group
  - `getent group <groupName>`
- Lock a user account
  - `usermod -L <userName>`

## Passwords

- Change current user's password
  - `passwd`
- Change another user's password (requires root or sudo)
  - `passwd <username>`
- Change root user's password
  - `sudo passwd`
