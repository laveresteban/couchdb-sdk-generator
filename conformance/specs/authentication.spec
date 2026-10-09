# Authentication

Tags: auth

## Cookie session login and logout
* Connect anonymously
* Log in with the admin credentials
* The session user is the admin user
* Log out
* The session user is anonymous

## Wrong password is rejected
* Connect anonymously
* Logging in with password "definitely-wrong" fails with status "401"
