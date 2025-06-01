// SPDX-License-Identifier: MIT
pragma solidity 0.8.24; // stating version

contract SimpleStorage {
    // favorite number initalized to 0 if no value
    uint256 myFavoriteNumber; // defaults to 0

    // uint256[] listOfFavoriteNumbers;
    struct Person{
        uint256 favoriteNumber;
        string name;
    }

    // dynamic array
    Person[] public listOfPeople;

    mapping(string => uint256) public nameToFavoriteNumber;

    // Person public pat = Person({favoriteNumber: 7, name: "Pat"});
    // Person public john = Person({favoriteNumber: 16, name: "john"});
    // Person public jacob = Person({favoriteNumber: 777, name: "jacob"});

    function store(uint256 _favoriteNumber) public virtual{
        myFavoriteNumber = _favoriteNumber; // + 5
    }

    // view, pure
    function retrieve() public view returns(uint256){
        return myFavoriteNumber;
    }

    function addPerson(string memory _name, uint256 _favoriteNumber) public {
        listOfPeople.push(Person(_favoriteNumber, _name));
        nameToFavoriteNumber[_name] = _favoriteNumber;
    }
}