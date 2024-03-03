// SPDX-License-Identifier: MIT
pragma solidity >= 0.7.0 < 0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract RoyaltyNFT is ERC721Enumerable, Ownable {

    bool public paused = false;
    mapping(address => uint256) private royaltysBalance;
    mapping(address => bool) private registered;
    address[] private ToBePaid;
    mapping(address => bool) private isToBePaid;
    uint256 private RoyaltiesSum = 0;
    mapping(uint256 => bool) private isSkillExists;

    struct Dependency {
        uint256 dependentSkill;
        uint256 allocation;
    }

    struct Skill {
        uint256 id;
        address[] authors;
        uint256[] allocation;
        Dependency[] dependencyTree;
    }

    Skill[] private skills;

      constructor() ERC721("ROYALTY MANAGEMENT", "RMN") Ownable(msg.sender) {
    }

    function getSkill(uint256 id) public view returns (
        uint256 , address[] memory, uint256[] memory, uint256[] memory, uint256[] memory
    ) {
        for(uint i = 0; i < skills.length; i++) {
            if (keccak256(abi.encodePacked(skills[i].id)) == keccak256(abi.encodePacked(id))) {
                // Create temporary arrays to hold Dependency fields
                uint256[] memory dependentSkills = new uint256[](skills[i].dependencyTree.length);
                uint256[] memory dependenciesAllocations = new uint256[](skills[i].dependencyTree.length);

                // Loop through the Dependency array and populate the temporary arrays
                for (uint j = 0; j < skills[i].dependencyTree.length; j++) {
                    dependentSkills[j] = skills[i].dependencyTree[j].dependentSkill;
                    dependenciesAllocations[j] = skills[i].dependencyTree[j].allocation;
                }

                return (skills[i].id, skills[i].authors, skills[i].allocation, dependentSkills, dependenciesAllocations);
            }
        }

        revert("Skill not found");
    }

    function donateSubSkill(uint256 id, uint256 wei_donation_amount) internal {
        require(isSkillExists[id], "This skill doesn't exist!");
        require(wei_donation_amount > 0, "Donation amount should be greater than 0");
        
        Skill memory skillToDonate;

        for (uint i = 0; i < skills.length; i++) {
            if (keccak256(abi.encodePacked(skills[i].id)) == keccak256(abi.encodePacked(id))) {
                skillToDonate = skills[i];
                break;
            }
        }

        for (uint i = 0; i < skillToDonate.allocation.length; i++) {
            royaltysBalance[skillToDonate.authors[i]] += (skillToDonate.allocation[i] * wei_donation_amount) / 100;

            if (!isToBePaid[skillToDonate.authors[i]]) {
                ToBePaid.push(skillToDonate.authors[i]);
                isToBePaid[skillToDonate.authors[i]] = true;
            }
        }
    }

    function donateSkill(uint256 id, uint256 donationAmount) public onlyOwner {
        require(!paused, "The contract is paused");
        require(isSkillExists[id], "This skill doesn't exist!");

        Skill memory skillToDonate;

        for (uint i = 0; i < skills.length; i++) {
            if (keccak256(abi.encodePacked(skills[i].id)) == keccak256(abi.encodePacked(id))) {
                skillToDonate = skills[i];
                break;
            }
        }

        require(skillToDonate.authors.length == skillToDonate.allocation.length, "Authors and allocation arrays mismatch. Shouldn't be here!");

        uint256 totalDependencyAllocation = 0;
        // Check if the dependencyTree array has a length > 0
        if(skillToDonate.dependencyTree.length > 0) {
            // Iterate through the length of the array and sum up the total allocation
            for (uint i = 0; i < skillToDonate.dependencyTree.length; i++) {
                totalDependencyAllocation += skillToDonate.dependencyTree[i].allocation;
                donateSubSkill(skillToDonate.dependencyTree[i].dependentSkill,((donationAmount * skillToDonate.dependencyTree[i].allocation) / 100));
            }
        }

        for (uint i = 0; i < skillToDonate.allocation.length; i++) {
            royaltysBalance[skillToDonate.authors[i]] += (skillToDonate.allocation[i] * donationAmount) / 100;

            if (!isToBePaid[skillToDonate.authors[i]]) {
                ToBePaid.push(skillToDonate.authors[i]);
                isToBePaid[skillToDonate.authors[i]] = true;
            }
        }

        RoyaltiesSum += donationAmount;
    }

    function isRegistered (address developer_wallet) public view returns (bool) {
        return registered[developer_wallet];
    }

    function checkBalance (address developer_wallet) public view returns (uint256) {
        require(registered[developer_wallet] == true, "Invalid developer address/ Not registered!");
        return royaltysBalance[developer_wallet];
    }

    function calculateTotalRoyalties() public view returns (uint256) {
        uint256 totalRoyalties = 0;
        // Iterate over all addresses in the ToBePaid array
        for (uint256 i = 0; i < ToBePaid.length; i++) {
            // Add the address's balance in the royaltyBalance mapping to the total
            totalRoyalties += royaltysBalance[ToBePaid[i]];
        }
        return totalRoyalties;
    }

    function RoyaltyDebt () public view returns (uint256) {
        return RoyaltiesSum;
    }

    function loadContract() public onlyOwner payable {
        require(msg.value == RoyaltiesSum, "Wrong amount of ether");
    }

    function distributeRoyalties() public onlyOwner {
        require(RoyaltiesSum <= address(this).balance, "Not enough Ether");

        uint256 i = 0;
        while (i < ToBePaid.length) {
            uint256 balance = royaltysBalance[ToBePaid[i]];
            require(
                balance > 0 && address(this).balance >= balance,
                "Insufficient contract balance to distribute royalties"
            );

            // Transfer the balance to the address
            (bool success,) = ToBePaid[i].call{value: balance}("");
            require(success, "Failed to send Ether");

            // Zero out the address's balance in the mapping
            royaltysBalance[ToBePaid[i]] = 0;
            isToBePaid[ToBePaid[i]] = false;
            ToBePaid[i] = ToBePaid[ToBePaid.length - 1];
            ToBePaid.pop();
        }
        RoyaltiesSum = 0;
    }

/*
  function withdrawBalance() public payable {

    require(registered[msg.sender], "You are not registered as a developer!");

    require(royaltysBalance[msg.sender] > 0.0001 ether, "Balance is less than 0.0001 ether");

    (bool success, ) = payable(msg.sender).call{value: royaltysBalance[msg.sender]}("");

    require(success);

    royaltysBalance[msg.sender] = 0;

  }
*/
function allocateRoyalty(uint256 id, uint256 newAllocation, address newAuthor) public {

    require(isSkillExists[id], "This skill doesn't exist!");
    require(registered[msg.sender], "You are not registered as a developer!");

    uint256 index;

    for (uint256 i = 0; i < skills.length; i++) {
        if (keccak256(abi.encodePacked(skills[i].id)) == keccak256(abi.encodePacked(id))) {
            index = i;
            break;
        }
    }

    // Find the author in the authors array of the found skill
    uint256 authorIndex;
    bool isAuthor = false;

    for (uint256 i = 0; i < skills[index].authors.length; i++) {
        if (skills[index].authors[i] == msg.sender) {
            authorIndex = i;
            isAuthor = true;
            break;
        }
    }

    require(isAuthor, "Sender is not an author of this skill");
    require(newAllocation >= 0, "New Allocation should be >= 0%");
    require(newAllocation <= skills[index].allocation[authorIndex], "Can't transfer more royalty points than you currently have.");

    // Author can renounce their allocation by setting newAllocation to 0
    if (newAllocation == 0) {

        uint256 renouncedAllocation = skills[index].allocation[authorIndex];

        // If the author is the sole author for this skill
        if (skills[index].authors.length == 1) {

            skills[index].authors.push(owner());
            skills[index].allocation.push(renouncedAllocation);

            // Move the last author to the deleted spot
            skills[index].authors[authorIndex] = skills[index].authors[skills[index].authors.length - 1];

            // Reduce authors array length by 1
            skills[index].authors.pop();

            // Move the last allocation to the deleted spot
            skills[index].allocation[authorIndex] = skills[index].allocation[skills[index].allocation.length - 1];

            // Reduce allocation array length by 1
            skills[index].allocation.pop();

            // Remove the author and their allocation
            if (registered[owner()] == false) {
                royaltysBalance[owner()] = 0;
                registered[owner()] = true;
            }
        }
        else {
            uint256 redistribution = renouncedAllocation / (skills[index].authors.length - 1);

            // Redistribute the renounced allocation among the remaining authors
            for (uint256 i = 0; i < skills[index].authors.length; i++) {
                if (i != authorIndex) {
                    skills[index].allocation[i] += redistribution;
                }
            }

            // If there is a remainder from the division, add it to the first author
            uint256 remainder = renouncedAllocation % (skills[index].authors.length - 1);

            // Remove the author and their allocation
            // Move the last author to the deleted spot
            skills[index].authors[authorIndex] = skills[index].authors[skills[index].authors.length - 1];

            // Reduce authors array length by 1
            skills[index].authors.pop();

            // Move the last allocation to the deleted spot
            skills[index].allocation[authorIndex] = skills[index].allocation[skills[index].allocation.length - 1];

            // Reduce allocation array length by 1
            skills[index].allocation.pop();

            skills[index].allocation[0] += remainder;
        }

    }
    // Or they can pass their allocation to another address
    else {

        if (newAllocation == skills[index].allocation[authorIndex]) {
            // Move the last author to the deleted spot
            skills[index].authors[authorIndex] = skills[index].authors[skills[index].authors.length - 1];

            // Reduce authors array length by 1
            skills[index].authors.pop();

            // Move the last allocation to the deleted spot
            skills[index].allocation[authorIndex] = skills[index].allocation[skills[index].allocation.length - 1];

            // Reduce allocation array length by 1
            skills[index].allocation.pop();
        }
        else {
            // Reduce the original author's allocation
            skills[index].allocation[authorIndex] -= newAllocation;
        }

        // Add the new author and their allocation
        bool exists = false;
        for (uint256 i = 0; i < skills[index].authors.length; i++) {
            if (skills[index].authors[i] == newAuthor) {
                exists = true;
                skills[index].allocation[i] += newAllocation;
                break;
            }
        }

        if (!exists) {
            skills[index].authors.push(newAuthor);
            skills[index].allocation.push(newAllocation);
        }

        if (registered[newAuthor] == false) {
            royaltysBalance[newAuthor] = 0;
            registered[newAuthor] = true;
        }
    }
}
/*
function renounceRoyalty(uint256 memory id) public {
    require(isSkillExists[id], "This skill doesn't exist!");
    require(registered[msg.sender], "You are not registered as a developer!");

    uint256 index;

    for (uint256 i = 0; i < skills.length; i++) {
        if (keccak256(abi.encodePacked(skills[i].id)) == keccak256(abi.encodePacked(id))) {
            index = i;
            break;
        }
    }

    // Find the author in the authors array of the found skill
    uint256 authorIndex;
    bool isAuthor = false;

    for (uint256 i = 0; i < skills[index].authors.length; i++) {
        if (skills[index].authors[i] == msg.sender) {
            authorIndex = i;
            isAuthor = true;
            break;
        }
    }

    require(isAuthor, "Sender is not an author of this skill");
    
    uint256 renouncedAllocation = skills[index].allocation[authorIndex];

    // If the author is the sole author for this skill
    if(skills[index].authors.length == 1) {
        skills[index].authors.push(owner());
        skills[index].allocation.push(renouncedAllocation);
    } else {
        uint256 redistribution = renouncedAllocation / (skills[index].authors.length - 1);

        // redistribute the renounced allocation among the remaining authors
        for (uint256 i = 0; i < skills[index].authors.length; i++) {
            if (i != authorIndex) {
                skills[index].allocation[i] += redistribution;
            }
        }

        // if there is a remainder from the division, add it to the first author
        uint256 remainder = renouncedAllocation % (skills[index].authors.length - 1);
        skills[index].allocation[0] += remainder;
    }

    // remove the author and their allocation
    delete skills[index].authors[authorIndex];
    delete skills[index].allocation[authorIndex];
}
*/

function getAuthorSkills(address author) public view returns (uint256[] memory, uint256[] memory) {
    // Initialize arrays for storing skill IDs and allocations.
    uint256[] memory authorSkillIds = new uint256[](skills.length);
    uint256[] memory authorAllocations = new uint256[](skills.length);

    // Counter for the number of skills the author is involved in
    uint256 count = 0;

    for (uint256 i = 0; i < skills.length; i++) {
        for (uint256 j = 0; j < skills[i].authors.length; j++) {
            if (skills[i].authors[j] == author) {
                // If the author is found, store the skill ID and allocation.
                authorSkillIds[count] = skills[i].id;
                authorAllocations[count] = skills[i].allocation[j];
                count++;
                break;
            }
        }
    }

    // Create new arrays with the exact count of the skills
    uint256[] memory finalSkillIds = new uint256[](count);
    uint256[] memory finalAllocations = new uint256[](count);

    // Copy the data to these new arrays
    for (uint256 i = 0; i < count; i++) {
        finalSkillIds[i] = authorSkillIds[i];
        finalAllocations[i] = authorAllocations[i];
    }

    return (finalSkillIds, finalAllocations);
}

//only owner
function mintSkill(uint256 id, address[] memory developer_wallets, uint256[] memory allocation, uint256[] memory dependentSkills, uint256[] memory dependency_allocations) public onlyOwner {
    require(!paused, "The contract is paused");
    require(!isSkillExists[id], "This skill already exists");
    require(developer_wallets.length == allocation.length, "Error. The amount of wallet addresses doesn't equal the amount of allocated distributions!");
    require(dependentSkills.length == dependency_allocations.length, "Error. The amount of dependent skills doesn't equal the amount of allocated distributions!");

    uint256 total_allocation_sum_dependencies = 0;
    for (uint i = 0; i < dependency_allocations.length; i++) {
        total_allocation_sum_dependencies += dependency_allocations[i];
    }
    require(total_allocation_sum_dependencies < 100, "The total sum of the dependancy percentages is over 100. Impossible");

    uint256 total_allocation_sum = 0;
    for (uint i = 0; i < allocation.length; i++) {
        total_allocation_sum += allocation[i];
    }
    require(total_allocation_sum + total_allocation_sum_dependencies == 100, "The total sum of ALL the percentages is not 100.");
    
    uint256 supply = totalSupply();
    for (uint j = 0; j < developer_wallets.length; j++) {
        if (registered[developer_wallets[j]] == false) {
            royaltysBalance[developer_wallets[j]] = 0;
            registered[developer_wallets[j]] = true;
        }
    }
    // Create new skill in storage
    skills.push();
    Skill storage newSkill = skills[skills.length - 1];
    
    // Assign fields
    newSkill.id = id;
    newSkill.authors = developer_wallets;
    newSkill.allocation = allocation;

    // Add dependencies
    for (uint i = 0; i < dependentSkills.length; i++) {
        require(isSkillExists[dependentSkills[i]], "Can not depend on a non-existing Skill");
        newSkill.dependencyTree.push(Dependency(dependentSkills[i], dependency_allocations[i]));
    }

    isSkillExists[id] = true;
    _safeMint(owner(), supply + 1);
}

function pause(bool _state) public onlyOwner {
    paused = _state;
}
  
}

