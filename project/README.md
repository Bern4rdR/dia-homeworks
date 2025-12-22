# Project Overview
## Authors
- [Bernard Rumar](mailto:bernardr@kth.se)
- [Bogdan Stefanescu](mailto:<!-- bogdan's email here -->@kth.se)
- [Vivienne Curewitz](mailto:curewitz@kth.se)

## Main Task
**Guests**
- Extrovert
- Introvert
- Grouping person
- Bartender
- Salesperson

**Traits**
- Extrovert
    - generocity
    - networking skills
    - TBD
- Introvert
    - social capacity
    - tiredness
    - TBD
- Grouping person
    - peer pressure theshold
    - ideal group size
    - TBD
- Bartender
    - drunk serving tolerance
    - charmed chance
    - TBD
- Salseperson
    - selling quota
    - target demographic
    - TBD

**Rules**
>Not sure if this is the right interpretation but it may only be necessary to have one rule for each combination of guests
- Extrovert
    - Introvert: may offer a drink based on `generocity`
    - Salesperson: may buy based on `generocity`
- Introvert
    - Grouping person: Will avoid if group size exceeds `social capacity`
    - Bartender: TBD
- Grouping person
    - Extrovert: will move towards extroverts to form a group with `ideal group size`
    - Salesperson: Will buy if other extroverts also buy based on `peer pressure threshold`
- Bartender
    - Extrovert: may still seell above `drunk serving tolerance` if they are easily `charmed`
    - Grouping person: will only sell if they're below `drunk serving tolerance`
- Salesperson
    - Introvert: TBD
    - Bartender: TBD
