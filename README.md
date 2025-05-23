# IPQualityScore for FreePBX

This script integrates IPQualityScore's spam validation with your FreePBX system. It's designed to help you filter out unwanted spam calls by checking incoming numbers against a spam database.

Sign up for an account that allows 1k queries a month:

* https://www.ipqualityscore.com/

-----

## Table of Contents

  * [Features](#features)
  * [Compatibility](#compatibility)
  * [How It Works](#how-it-works)
  * [Installation](#installation)
  * [Configuration](#configuration)
  * [Testing](#testing)
  * [License](#license)

-----

## Features

  * **Spam Call Filtering**: Automatically checks incoming calls for a spam score.
  * **Dynamic Blacklisting**: Adds high-scoring spam numbers to your FreePBX blacklist.
  * **Caller Whitelisting**: Allows legitimate callers to easily add themselves to your phonebook.
  * **Configurable Threshold**: Adjust the spam score threshold to suit your needs.

-----

## Compatibility

This script has been tested with **Incredible PBX 2027-U 16.0.40.13**. It should be compatible with most FreePBX installations running Asterisk 16 or newer.

-----

## How It Works

When a call comes into your FreePBX system:

1.  **Phonebook Check**: The script first checks if the **caller's number is already in your FreePBX phonebook or FreePBX Blacklist**.
      * If it is in the phonebook, the call is immediately routed to the specified extension.
      * If it is in the blacklist, the call is sent to "no service"
2.  **Spam Validation**: If the caller's number is **not in your phonebook/Blacklist**, the `ipqs_validate.sh` script executes. This script sends the caller's number to IPQualityScore for a spam score.
3.  **Spam Handling**:
      * If the **spam score is above your configured threshold** (default: 38), the number is marked as spam, the caller ID is updated (e.g., `SPAM:CALLERNAME`), and the number is added to your FreePBX blacklist.
      * If the **spam score is below the threshold**, the caller is prompted to press '5'.
          * If they **press '5'**, their number is **added to your FreePBX phonebook**, ensuring they won't be challenged again.
          * If they **don't respond**, they receive a "no service" message and will need to call back.

Here's the relevant Asterisk dialplan logic:

```extensions_custom.conf
exten => spam,n,AGI(ipqs_validate.sh,${CALLERID(number)})
exten => spam,n,ExecIf($[${SPAMSCORE} > 0]?Set(CDR(userfield)=SCORE:${SPAMSCORE}))
exten => spam,n,ExecIf($[${SPAMSCORE} > 38]?Set(CALLERID(name)=SPAM:${CALLERID(name)}))
exten => spam,n,ExecIf($[${SPAMSCORE} > 38]?Set(DB(blacklist/${CALLERID(number)})=1))
exten => spam,n,NoOp(About to check for spam)
exten => spam,n,GotoIf($[${SPAMSCORE} > 38]?FLUNKED)
```

**Note on Threshold**: I've set the initial threshold to **38**. When you first deploy this, I recommend setting it to **90**. After observing its behavior with your incoming calls, you can gradually lower it to fine-tune your spam filtering.

-----

## Installation

Follow these steps to install and configure the IPQualityScore script:

1.  **Modify `extensions_custom.conf`**:
    Add the contents of `SPAM-extensions_custom.conf` to the end of your `/etc/asterisk/extensions_custom.conf` file.

2.  **Configure Dialed Numbers**:
    Within `extensions_custom.conf` (or wherever your inbound routes are defined), ensure you specify your actual dialed-in numbers and route them to the appropriate extensions. Replace `9999999999` with your inbound DIDs:

    ```extensions_custom.conf
    exten => spam,n,GotoIf($["${DIDN}" = "9999999999"] ?from-trunk,100,1) ; if this number was dialed in pass to extension 100
    exten => spam,n,GotoIf($["${DIDN}" = "9999999999"] ?from-trunk,400,1) ; if this number was dialed in pass to extension 400
    exten => spam,n,GoTo(from-trunk,100,1) ; Default fallback if neither number matches
    ```

3.  **Copy `ipqs_validate.sh`**:
    Copy the `ipqs_validate.sh` script to your Asterisk AGI-bin directory:

    ```bash
    sudo cp ipqs_validate.sh /var/lib/asterisk/agi-bin/
    sudo chmod +x /var/lib/asterisk/agi-bin/ipqs_validate.sh
    ```
4. **Copy `fiveV2.wav` to `/etc/asterisk/`**:
   Copy the `fiveV2.wav` spam audio challange to  Asterisk directory:

    ```bash
    sudo cp fiveV2.wav /etc/asterisk
    ```

5. **Add your API to `ipqs_validate.sh`**:
     Add your API KEY from * https://www.ipqualityscore.com/

     I found my API key, left side "Settings & Account Management" and then API KEYS
-----

## Configuration

1.  **Configure `ipqs_validate.sh`**:
    Edit the `ipqs_validate.sh` script to add any numbers you wish to whitelist. These numbers will always bypass the spam check.

    ```bash
    # --- Whitelist Check ---
    # Add numbers here that should always be considered "OK"
    # Provide a comma-separated list of whitelisted numbers
    WHITELIST_NUMBERS="5551234567,8005551212"
    ```

2.  **Add a Custom Destination in FreePBX**:
    Navigate to **Admin** \> **Custom Destinations** in your FreePBX GUI and add a new custom destination with these details:

      * **Target**: `spam,spam,1`
      * **Description**: `spam,spam,1`
      * **Notes**: `spam,spam,1`
      * **Return**: `No`
      * **Destination**: Select an appropriate extension (e.g., `Extensions`, then choose the extension where valid calls should go).

3.  **Modify Inbound Routes**:
    Go to **Connectivity** \> **Inbound Routes** in FreePBX. For the inbound route you want to protect, set the **Destination** at the bottom to **Custom Destinations** and select the `spam,spam,1` custom destination you created.

4. **Reload PBX**:

```bash
    fwconsole restart
```
-----

## Testing

To verify your setup, you can use a known spam number from a reputable source like [Norton LifeLock](https://lifelock.norton.com/learn/fraud/scam-call-numbers).

From your FreePBX command line, run the `ipqs_validate.sh` script with a test number:

```bash
/var/lib/asterisk/agi-bin/ipqs_validate.sh 2022217923
```

You should see output similar to this, indicating the spam score:

```
SET VARIABLE SPAMSCORE 100
SET VARIABLE SPAM SPAM
```

-----

## License

This project is open-source and available under the [MIT License](LICENSE.md).
