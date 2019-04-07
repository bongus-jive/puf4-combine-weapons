require "/scripts/util.lua"
require "/scripts/interp.lua"

-- Base gun fire ability
GunFire = WeaponAbility:new()

function GunFire:init()
  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self.fireTime
	
	ammo = tonumber(animator.animationState("ammo"))

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

function GunFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end
	
	if ammo == 0 and animator.animationState("body") == "idle" and self.cooldownTimer == 0 and not status.resourceLocked("energy") then
		animator.setAnimationState("body", "reload1")
		animator.playSound("reload1")
		self:setState(self.reload)
	elseif ammo ~= 6 and animator.animationState("body") == "reload2" and not status.resourceLocked("energy") then
		status.overConsumeResource("energy", 5.5)
		ammo = ammo + 0.25
	elseif ammo > 6 then
		ammo = 6
	end
	
	if 0 <= ammo and ammo <= 6 then
		activeItem.setCursor("/combine/burstrifle/cursor/"..tostring(math.floor(ammo))..".cursor")
		animator.setAnimationState("ammo", tostring(math.floor(ammo)))
	end

  if self.fireMode == ("primary") and (not self.shiftHeld or ammo == 6 or status.resourceLocked("energy"))
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
		and animator.animationState("body") == "idle"
		and ammo > 0
    and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
		
		status.setResourcePercentage("energyRegenBlock", 0.6)
    self:setState(self.auto)
  end
	
	if self.fireMode == ("primary") and	self.shiftHeld and not status.resourceLocked("energy")
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
		and ammo ~= 6
		and animator.animationState("body") == "idle" then
		
		animator.setAnimationState("body", "reload1")
		animator.playSound("reload1")
		self:setState(self.reload)
	end

	 if self.fireMode == ("alt")
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
		and animator.animationState("body") == "idle"
		and not status.resourceLocked("energy")
    and not world.lineTileCollision(mcontroller.position(), self:altPosition())
    and not world.lineTileCollision(mcontroller.position(), self:firePosition())
		and status.overConsumeResource("energy", 69420666) then
		
    self:setState(self.alt)
  end
end

function GunFire:auto()
  self.weapon:setStance(self.stances.fire)

  self:fireProjectile()
  self:muzzleFlash()

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function GunFire:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

  local progress = 0
  util.wait(self.stances.cooldown.duration, function()
    local from = self.stances.cooldown.weaponOffset or {0,0}
    local to = self.stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.weaponRotation, self.stances.idle.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.armRotation, self.stances.idle.armRotation))

    progress = math.min(1.0, progress + (self.dt / self.stances.cooldown.duration))
  end)
end

function GunFire:reload()
  self.weapon:setStance(self.stances.reload)
  self.weapon:updateAim()

  local progress = 0
  util.wait(self.stances.reload.duration, function()
    local from = self.stances.idle.weaponOffset or {0,0}
    local to = self.stances.reload.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.idle.weaponRotation, self.stances.reload.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.idle.armRotation, self.stances.reload.armRotation))

    progress = math.min(1.0, progress + (self.dt / self.stances.reload.duration))
  end)
	
	util.wait(0.4)
	animator.playSound("reload2")
	
	self:setState(self.load)
end

function GunFire:load()
  self.weapon:setStance(self.stances.load)
  self.weapon:updateAim()

  local progress = 0
  util.wait(self.stances.load.duration, function()
    local from = self.stances.reload.weaponOffset or {0,0}
    local to = self.stances.load.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.reload.weaponRotation, self.stances.load.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.reload.armRotation, self.stances.load.armRotation))

    progress = math.min(1.0, progress + (self.dt / self.stances.reload.duration))
  end)
	
	self.cooldownTimer = self.fireTime / 1.5
	self.weapon:setStance(self.stances.load)
end

function GunFire:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.playSound("fire")

  animator.setLightActive("muzzleFlash", true)
end

function GunFire:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = self:damagePerShot()
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)

  if not projectileType then
    projectileType = self.projectileType
  end
  if type(projectileType) == "table" then
    projectileType = projectileType[math.random(#projectileType)]
  end
	
	ammo = ammo - 1

  local projectileId = 0
  for i = 1, (projectileCount or self.projectileCount) do
    if params.timeToLive then
      params.timeToLive = util.randomInRange(params.timeToLive)
    end

    projectileId = world.spawnProjectile(
        projectileType,
        firePosition or self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(inaccuracy or self.inaccuracy),
        false,
        params
      )
  end
  return projectileId
end

function GunFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function GunFire:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function GunFire:energyPerShot()
  return self.energyUsage * self.fireTime * (self.energyUsageMultiplier or 1.0)
end

function GunFire:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.fireTime)) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
end

function GunFire:uninit()
end

function GunFire:alt()
	animator.playSound("alt")
  --animator.burstParticleEmitter("charge")
	
  self.weapon:setStance(self.stances.fire)

  self:altFire()

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end
  self.cooldownTimer = self.fireTime * 2.5
  self:setState(self.cooldown)
end

function GunFire:altFire(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
  local params = sb.jsonMerge(self.altParams, projectileParams or {})
  params.power = self:damagePerShot() * 69420
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)

  if not projectileType then
    projectileType = self.projectileAlt
  end
  if type(projectileType) == "table" then
    projectileType = projectileType[math.random(#projectileType)]
  end

  local projectileId = 0
  for i = 1, (projectileCount or self.altCount) do
    if params.timeToLive then
      params.timeToLive = util.randomInRange(params.timeToLive)
    end

    projectileId = world.spawnProjectile(
        projectileType,
        firePosition or self:altPosition(),
        activeItem.ownerEntityId(),
        self:aimVector(inaccuracy or self.inaccuracy),
        false,
        params
      )
  end
  return projectileId
end

function GunFire:altPosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleAlt))
end