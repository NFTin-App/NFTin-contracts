// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {DataTypes} from "./DataTypes.sol";

contract NFTinStorage {
    constructor() {}

    address signer;
    mapping(uint256 => uint256) public rating; //???
    mapping(address => uint256) public profiles; //wallet => profile
    // mapping(uint256 => Posts[]) public posts; // profile => post
    mapping(uint256 => uint256[]) public postList; //profile => [postId]
    mapping(uint256 => uint256[]) public collections; //profile => posts
    mapping(uint256 => mapping(uint256 => Comments[])) public comments; //profile => post => comments[]
    mapping(uint256 => Mirrors[]) public mirrors; //profile => mirrors
    mapping(uint256 => mapping(uint256 => mapping(uint256 => bool)))
        public likes; //profile => post => profile => like
    mapping(uint256 => mapping(uint256 => uint256)) public likesCount; //profile => pub => count
    mapping(uint256 => mapping(uint256 => uint256)) public pubRating;
    mapping(uint256 => uint256[]) public activityPerDay; //profile => timestamp
    //mapping(uint256 => uint256) public tokensPerDay; //??
    mapping(uint256 => uint256) public rewardBalances; //profile => avalable rewards    
    mapping(uint256 => uint256[]) public rewardsTime;   //profile => timestamp[]
    mapping(uint256 => uint256[]) public rewardsValue; //profile => value[]
    mapping(uint256 => uint256) public lastRewardRating;



    //balanse
    //basalnse today
    //timestamp

    struct Mirrors {
        uint256 mirrorId;
        uint256 profileIdPointed;
        uint256 pubIdPointed;
    }

    struct Comments {
        uint256 profileId;
        uint256 profileIdPointed; //??
        uint256 pubId;
        uint256 pubIdPointed;
    }

    modifier profileOwner(uint256 _profileId) {
        require(profiles[msg.sender] == _profileId, "Not an owner");
        _;
    }

    modifier pubExist(uint256 _profileIdPointed, uint256 _pubIdPointed) {
        uint256[] memory _postList = postList[_profileIdPointed];
        bool _pubExist;
        for (uint256 i = 0; i < _postList.length; i++) {
            // need gas op
            if (_postList[i] == _pubIdPointed) _pubExist = true;
        }
        require(_pubExist, "Pub doesn`t exist");
        _;
    }

    modifier activityCount(uint256 _profileId) {
        uint256 _activites;
        if (activityPerDay[_profileId].length > 24) {
            for (
                uint256 j = activityPerDay[_profileId].length - 25;
                j < activityPerDay[_profileId].length;
                j++
            ) {
                if (activityPerDay[_profileId][j] > block.timestamp - 1 days) {
                    _activites++;
                }
            }

            require(_activites > 0, "No more activities");
        }
        _;
    }


    event profileOnboarded(
        address indexed _profileAddress,
        uint256 indexed _profileId
    );

    event posted(
        address indexed _profileAddress,
        DataTypes.PostData indexed _data
    );

    event commented(
        address indexed _profileAddress,
        DataTypes.CommentData indexed _data
    );

    event mirrored(
        address indexed _profileAddress,
        DataTypes.MirrorData indexed _data
    );

    event liked(
        address indexed _profileAddress,
        uint256 indexed _profileIdPointed,
        uint256 indexed _pubIdPointed
    );
}

// todo:
// write tests
// revards logic
// control mechanism
// owner, profile owner
