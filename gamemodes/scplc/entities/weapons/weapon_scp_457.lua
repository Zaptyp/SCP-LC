SWEP.Base 		= "weapon_scp_base"
SWEP.PrintName	= "SCP-457"

SWEP.HoldType	= "normal"

SWEP.Traps = {}
SWEP.MaxTraps = 5
SWEP.TrapCD = 0

SWEP.NextDMG = 0
SWEP.NCheck = 0

function SWEP:SetupDataTables()
	self:AddNetworkVar( "Traps", "Int" )
end

function SWEP:Initialize()
	self:SetHoldType( self.HoldType )
	self:InitializeLanguage( "SCP457" )
end

function SWEP:Think()
	if SERVER then
		if self.Owner:WaterLevel() > 0 then
			if self.NextDMG < CurTime() and self.Owner:Health() > 1 then
				self.NextDMG = CurTime() + 0.1
				self.Owner:SetHealth( math.max( 1, self.Owner:Health() - 20 ) )
			end
		elseif !self.Owner:IsBurning() then
			local rad = 125 + ( self:GetUpgradeMod( "firerad" ) or 0 )
			local dmg = 2 + ( self:GetUpgradeMod( "firedmg" ) or 0 )

			local fire = self.Owner:Burn( -3, rad, self.Owner, dmg )
			fire:SetShouldHurtOwner( false )
		end

		if self.NCheck < CurTime() then
			self.NCheck = CurTime() + 1

			for i = #self.Traps, 1, -1 do
				if !IsValid( self.Traps[i] ) then
					table.remove( self.Traps, i )
				end
			end

			self:SetTraps( #self.Traps )
		end
	end
end

function SWEP:SecondaryAttack()
	if self.TrapCD > CurTime() then return end

	local hp = self.Owner:Health()
	local maxhp = self.Owner:GetMaxHealth()

	if hp <= maxhp * 0.1 then return end

	local tr = util.TraceLine{
		start = self.Owner:GetShootPos(),
		endpos = self.Owner:GetShootPos() + self.Owner:GetAimVector() * 175,
		mask = MASK_SOLID_BRUSHONLY
	}

	if tr.Hit and tr.HitNormal.z > 0.35 then
		self.TrapCD = CurTime() + 8

		if SERVER then
			for i, v in pairs( ents.FindInSphere( tr.HitPos, 125 ) ) do
				if string.find( v:GetName(), "elev_" ) then
					return
				end
			end

			local traps = #self.Traps

			if traps >= self.MaxTraps then
				local oldest = table.remove( self.Traps, 1 )

				if IsValid( oldest ) then
					oldest:Remove()
				end
			end

			local lifetime = 180 + ( self:GetUpgradeMod( "traptime" ) or 0 )
			local burntime = 1.5 + ( self:GetUpgradeMod( "trapburn" ) or 0 )
			local dmg = 4 + ( self:GetUpgradeMod( "trapdmg" ) or 0 )

			local trap = ents.Create( "slc_fire_trap" )
			trap:SetPos( tr.HitPos )
			trap:SetOwner( self.Owner )
			trap:SetLifeTime( lifetime )
			trap:SetBurnTime( burntime )
			trap:SetDamage( dmg )
			trap:Spawn()

			table.insert( self.Traps, trap )

		end

		self:SetTraps( math.min( self:GetTraps() + 1, self.MaxTraps ) )
		self.Owner:SetHealth( hp - maxhp * 0.02 )
	end
end

local color_red = Color( 255, 0, 0 )
local color_green = Color( 0, 255, 0 )
function SWEP:DrawSCPHUD()
	//if hud_disabled or HUDDrawInfo or ROUND.preparing then return end

	local txt, color
	if self.TrapCD > CurTime() then
		txt = string.format( self.Lang.swait, math.ceil( self.TrapCD - CurTime() ) )
		color = color_red
	elseif self.Owner:Health() <= self.Owner:GetMaxHealth() * 0.1 then
		txt = self.Lang.nohp
		color = color_red
	else
		txt = self.Lang.sready
		color = color_green
	end

	local tw, th = draw.Text{
		text = txt,
		pos = { ScrW() * 0.5, ScrH() * 0.97 },
		color = color,
		font = "SCPHUDSmall",
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER,
	}

	draw.Text{
		text = string.format( self.Lang.placed, self:GetTraps(), self.MaxTraps ),
		pos = { ScrW() * 0.5, ScrH() * 0.97 - th },
		color = color_green,
		font = "SCPHUDSmall",
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER,
	}
end

SCPHook( "SCP457", "EntityTakeDamage", function( ply, dmg )
	if !ply:IsPlayer() then return end
	if ply:SCPClass() == CLASSES.SCP457 then
		if dmg:IsDamageType( DMG_BURN ) then
			return true
		end
	end
end )

SCPHook( "SCP457", "SLCFireOnBurnPlayer", function( fire, target, dmg )
	local owner = fire:GetOwner()

	if owner:IsPlayer() and owner:SCPClass() == CLASSES.SCP457 then
		local heal = 2

		local wep = owner:GetActiveWeapon()
		if wep.UpgradeSystemMounted then
			wep:AddScore( dmg:GetDamage() )
			heal = heal + ( wep:GetUpgradeMod( "heal" ) or 0 )
		end

		local hp = owner:Health() + heal
		local max = owner:GetMaxHealth()

		if hp > max then
			hp = max
		end

		owner:SetHealth( hp )
	end
end )

SCPHook( "SCP457", "DoPlayerDeath", function( ply, attacker, info )
	if attacker:IsPlayer() and attacker:SCPClass() == CLASSES.SCP457 then
	 	AddRoundStat( "457" )
	end
end )

--Can't use SCPHook because it is added too late
hook.Add( "SLCOnEntityIgnited", "SCP457", function( ent, fire )
	//print( "ENT IGNITED!", ent, fire, ent:SCPClass() )
	if CLIENT and ent == LocalPlayer() then
		if ent:SCPClass() == CLASSES.SCP457 then
			fire:SetShouldCreateParticles( false )
		end
	end
end )

/*SCPHook( "SCP457", "CanPlayerSeePlayer", function( ply, target )
	if target:SCPClass() == CLASSES.SCP457 then
		return false
	end
end )*/

DefineUpgradeSystem( "scp457", {
	grid_x = 4,
	grid_y = 3,
	upgrades = {
		{ name = "fire1", cost = 1, req = {}, reqany = false,  pos = { 1, 1 }, mod = { firerad = 50 }, active = true },
		{ name = "fire2", cost = 3, req = { "fire1" }, reqany = false,  pos = { 1, 2 }, mod = { firedmg = 0.5 }, active = true },
		{ name = "fire3", cost = 5, req = { "fire2" }, reqany = false,  pos = { 1, 3 }, mod = { firedmg = 1, firerad = 75 }, active = true },

		{ name = "trap1", cost = 1, req = {}, reqany = false,  pos = { 3, 1 }, mod = { traptime = 60, trapburn = 1 }, active = false },
		{ name = "trap2", cost = 2, req = { "trap1" }, reqany = false,  pos = { 3, 2 }, mod = { traptime = 120, trapburn = 2, trapdmg = 0.5 }, active = false },
		{ name = "trap3", cost = 4, req = { "trap2" }, reqany = false,  pos = { 3, 3 }, mod = { trapburn = 3, trapdmg = 1 }, active = false },

		{ name = "heal1", cost = 2, req = { "fire1", "trap1" }, reqany = true,  pos = { 2, 2 }, mod = { heal = 1 }, active = false },
		{ name = "heal2", cost = 4, req = { "heal1" }, reqany = false,  pos = { 2, 3 }, mod = { heal = 2 }, active = false },

		{ name = "speed", cost = 3, req = {}, reqany = false,  pos = { 4, 1 }, mod = {}, active = true },
		{ name = "outside_buff", cost = 1, req = {}, reqany = false,  pos = { 4, 2 }, mod = {}, active = false },
	},
	rewards = {
		{ 50, 1 },
		{ 100, 1 },
		{ 200, 1 },
		{ 300, 1 },
		{ 400, 1 },
		{ 500, 1 },
		{ 750, 2 },
		{ 1000, 3 },
		{ 1500, 3 },
	}
} )

function SWEP:OnUpgradeBought( name, info, group )
	if SERVER and self:CheckOwner() then
		if name == "speed" then
			self.Owner:PushSpeed( 1.1, 1.1, -1, "SLC_SCP457" )
		else
			self.Owner:StopBurn()
		end
	end
end

InstallUpgradeSystem( "scp457", SWEP )