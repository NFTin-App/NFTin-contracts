// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {LensInteractions} from "./LensInteractions.sol";
import {DataTypes} from "./DataTypes.sol";
import {INFTinLogic} from "./INFTinLogic.sol";
import {NFTsInteractions} from "./NFTsInteractions.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NFTinLogic is LensInteractions, NFTsInteractions {

        constructor() {
        owner = msg.sender;
    }

    function onboardNewProfile(uint256 _profileId) external {
        require(ownerOf(_profileId) == msg.sender, "not an owner");
        profiles[msg.sender] = _profileId;
        if (!isOnboarded[msg.sender]) {
            _registrationBonus(msg.sender);
            isOnboarded[msg.sender] = true;
        }
    }

    function setPost(
        DataTypes.PostData memory vars,
        address _nftAddress,
        uint256 _tokenId,
        nftType _type
    ) external profileOwner(vars.profileId) {
        require(
            isNftOwner(_nftAddress, msg.sender, _tokenId, uint8(_type)),
            "Not owner of NFT"
        );
        vars.contentURI = getNftUri(_nftAddress, _tokenId, uint8(_type));
        uint256 _cost = getPostCost(vars.profileId);
        require(
            IERC20(tinToken).balanceOf(msg.sender) >= _cost,
            "not enough token"
        );
        (bool success, uint256 _postId) = post(vars);
        require(success, "Transaction failed");
        getFee(msg.sender, _cost);
        postList[vars.profileId].push(_postId);
        NFTstruct memory _nfts;
        _nfts.nftAddress = _nftAddress;
        _nfts.tokenId = _tokenId;
        _nfts.postId = _postId;
        _nfts.nftType = _type;
        nfts[vars.profileId].push(_nfts);
        postEnable[vars.profileId][_postId] = true;
    }

    function setComment(DataTypes.CommentData calldata vars)
        external
        profileOwner(vars.profileId)
        pubExist(vars.profileIdPointed, vars.pubIdPointed)
        activityCount(vars.profileId)
    {
        uint256 _cost = getActivityCost(
            vars.profileIdPointed,
            vars.pubIdPointed
        );
        (bool success, uint256 _commentId) = comment(vars);
        require(success, "transaction failed");
        getFee(msg.sender, _cost);
        Comments memory _comment;
        _comment.profileId = vars.profileId;
        _comment.profileIdPointed = vars.profileIdPointed;
        _comment.pubId = _commentId;
        _comment.pubIdPointed = vars.pubIdPointed;
        comments[vars.profileIdPointed][vars.pubIdPointed].push(_comment);
        addRating(vars.profileIdPointed, vars.pubIdPointed);
        activityPerDay[vars.profileId].push(block.timestamp);
    }

    function setMirror(DataTypes.MirrorData calldata vars)
        external
        profileOwner(vars.profileId)
        pubExist(vars.profileIdPointed, vars.pubIdPointed)
        activityCount(vars.profileId)
    {
        uint256 _cost = getActivityCost(
            vars.profileIdPointed,
            vars.pubIdPointed
        );
        (bool success, uint256 _mirrorId) = mirror(vars);
        require(success, "transaction failed");
        getFee(msg.sender, _cost);
        Mirrors memory _mirror;
        _mirror.profileIdPointed = vars.profileIdPointed;
        _mirror.pubIdPointed = vars.pubIdPointed;
        _mirror.mirrorId = _mirrorId;
        mirrors[vars.profileId].push(_mirror);
        addRating(vars.profileIdPointed, vars.pubIdPointed);
        activityPerDay[vars.profileId].push(block.timestamp);
    }

    function setLike(
        uint256 _profileId,
        uint256 _profileIdPointed,
        uint256 _postId
    )
        external
        profileOwner(_profileId)
        pubExist(_profileIdPointed, _postId)
        activityCount(_profileId)
    {
        uint256 _cost = getActivityCost(_profileIdPointed, _postId);
        require(
            !likes[_profileIdPointed][_postId][_profileId],
            "Like setted yet"
        );
        getFee(msg.sender, _cost);
        likes[_profileIdPointed][_postId][_profileId] = true;
        likesCount[_profileIdPointed][_postId]++;
        addRating(_profileIdPointed, _postId);
        activityPerDay[_profileId].push(block.timestamp);
    }

    function getReward(uint256 _profileId) external profileOwner(_profileId) {
        require(ownerOf(_profileId) == msg.sender, "Not a lens profile owner");
        uint256 rewardsAlready;
        uint256 rewardAvailable = getRewardValue(_profileId, msg.sender);
        if (rewardAvailable == 0) {
            //  revert("Not available rewards");
            return;
        }
        for (uint256 i = 0; i < rewardsTime[_profileId].length; i++) {
            if (rewardsTime[_profileId][i] > block.timestamp - 1 days) {
                rewardsAlready += rewardsValue[_profileId][i];
            }
        }
        require(rewardsAlready < dailyRewardLimit, "No more rewards today");
        if (rewardsAlready + rewardAvailable >= dailyRewardLimit) {
            _revard(msg.sender, dailyRewardLimit - rewardsAlready);
            rewardsValue[_profileId].push(dailyRewardLimit - rewardsAlready);
        } else {
            _revard(msg.sender, rewardAvailable);
            rewardsValue[_profileId].push(rewardAvailable);
        }
        rewardsTime[_profileId].push(block.timestamp);

        lastRewardRating[_profileId] = rating[_profileId];
    }

    function createCollection(uint256 _profileId, uint256[] calldata _posts)
        external
    {
        uint256 _length = _posts.length;
        uint256[] memory _postList = postList[_profileId];
        bool _pubExist;
        bool _duplicate;

        for (uint256 i = 0; i < _length; i++) {
            _pubExist = false;
            for (uint256 j = 0; j < _postList.length; j++) {
                if (_postList[j] == _posts[i]) _pubExist = true;
            }
            require(_pubExist, "Pub doesn`t exist");

            for (uint256 k = 0; k < _length; k++) {
                if (i != k) {
                    if (_posts[i] == _posts[k]) {
                        _duplicate = true;
                    }
                }
            }
            require(!_duplicate, "Duplicate");
        }
        collectionsNum[_profileId]++;
        collectionsCounter++;
        for (uint256 i = 0; i < _length; i++) {
            collections[_profileId][collectionsNum[_profileId]].push(_posts[i]);
        }

        collectionStruct storage _newCollection = collectionsById[collectionsCounter];
        _newCollection.id = collectionsCounter;
        _newCollection.profileId = _profileId;
        _newCollection.collectionNum = collectionsNum[_profileId];

        collectionsList.push(collectionsCounter);
    }

    function shuffleCollections() public {
        (, bytes memory data) = vrfContract.call(
            abi.encodeWithSignature(
                "requestRandomWords()" 
            )
        );
        uint256 _id = abi.decode(data, (uint256));
        (, data) = vrfContract.call(
            abi.encodeWithSignature(
                "getRequestStatus(uint256)" , _id
            )
        );
        uint256 _rundomNum = abi.decode(data, (uint256));

        for (uint256 i = 0; i < collectionsList.length; i++) {
            uint256 n = i + _rundomNum % (collectionsList.length - i);
            uint256 temp = collectionsList[n];
            collectionsList[n] = collectionsList[i];
            collectionsList[i] = temp;
        }
    }

    function disablePost(uint256 _profileId, uint256 _postId)
        external
    // ownerOrAdmin
    {
        postEnable[_profileId][_postId] = false;
        remooveRating(_profileId, _postId, pubRating[_profileId][_postId]);
    }

    function getPostList(uint256 _profileId)
        external
        view
        returns (uint256[] memory)
    {
        uint256 len = postList[_profileId].length;
        uint256[] memory _listFiltered = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            if (postEnable[_profileId][postList[_profileId][i]]) {
                _listFiltered[i] = postList[_profileId][i];
            } else {
                _listFiltered[i] = 0;
            }
        }
        return _listFiltered;
    }

    function getMirrors(uint256 _profileId)
        external
        view
        returns (Mirrors[] memory)
    {
        return mirrors[_profileId];
    }

    function getComments(uint256 _profileId, uint256 _postId)
        external
        view
        returns (Comments[] memory)
    {
        return comments[_profileId][_postId];
    }

    function getProfile(address _profileAddress)
        external
        view
        returns (uint256)
    {
        return profiles[_profileAddress];
    }

    function getRating(uint256 _profileId) public view returns (uint256) {
        return rating[_profileId];
    }

    function _revard(address _user, uint256 _amount) internal {
        (bool success, ) = tinToken.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                owner,
                _user,
                _amount
            )
        );
        require(success, "Transaction failed");
    }

    function getRewardValue(uint256 _profileId, address _user)
        internal
        returns (uint256)
    {
        uint256[] memory notOwnerNfts = new uint256[](nfts[_profileId].length);
        uint256 j;

        for (uint256 i = 0; i < nfts[_profileId].length; i++) {
            if (
                !isNftOwner(
                    nfts[_profileId][i].nftAddress,
                    _user,
                    nfts[_profileId][i].tokenId,
                    uint8(nfts[_profileId][i].nftType)
                )
            ) {
                notOwnerNfts[j] = i;
                j++;
                remooveRating(
                    _profileId,
                    nfts[_profileId][i].postId,
                    pubRating[_profileId][nfts[_profileId][i].postId]
                );
                if (
                    lastRewardRating[_profileId] >
                    pubRating[_profileId][nfts[_profileId][i].postId]
                ) {
                    lastRewardRating[_profileId] =
                        lastRewardRating[_profileId] -
                        pubRating[_profileId][nfts[_profileId][i].postId];
                } else {
                    lastRewardRating[_profileId] = 0;
                }
            }
        }

        uint256 _rating = rating[_profileId] - lastRewardRating[_profileId];
        return (_rating * 1 ether) / rewardsScaler;
    }

    function getCollection(uint256 _profileId, uint256 _collectionId) external view returns(uint256[] memory){
        return collections[_profileId][_collectionId];
    }

    function getCollectionById(uint256 _id) external view returns(uint, uint, uint[] memory){
        uint256[] memory _posts = collections[collectionsById[_id].profileId][collectionsById[_id].collectionNum];
        return (collectionsById[_id].profileId, collectionsById[_id].collectionNum, _posts);
    }

    function getPostCost(uint256 _profileId) internal view returns (uint256) {
        if (rating[_profileId] != 0) {
            return (rating[_profileId] * 1 ether) / postPriceScaler;
        } else {
            return 1 ether / postPriceScaler;
        }
    }

    function getCollectionsList() external view returns (uint256[] memory){
        return collectionsList;
    }

    function getActivityCost(uint256 _profileIdPointed, uint256 _pubIdPointed)
        internal
        view
        returns (uint256)
    {
        return
            (1 ether + pubRating[_profileIdPointed][_pubIdPointed]) /
            activityPriceScaler;
    }

    function addRating(uint256 _profile, uint256 _pubId) internal {
        rating[_profile]++;
        pubRating[_profile][_pubId]++;
    }

    function _registrationBonus(address _newUser) internal {
        // ??
        (bool success, ) = tinToken.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                owner,
                _newUser,
                registrationBonus
            )
        );
        require(success, "Transaction failed");
    }

    function getFee(address _user, uint256 _amount) internal {
        (bool success, ) = tinToken.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                _user,
                owner,
                _amount
            )
        );
        require(success, "Transaction failed");
    }

    function remooveRating(
        uint256 _profile,
        uint256 _pubId,
        uint256 _amount
    ) internal {
        rating[_profile] -= _amount;
        pubRating[_profile][_pubId] -= _amount;
    }
}
