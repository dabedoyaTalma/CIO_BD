/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_ServiceTypeV2]    Script Date: 12/05/2023 10:58:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ===================================================================================================================================================================================	
-- Description: Function for Businees Rules "ServiceType"
-- Change History:
--	2021-11-XX	XXXXXXXX: Funtion created
--	2021-12-16	Sebastián Jaramillo: Se incluye RN Contrato Nuevo SARPA
--	2021-12-16	Sebastián Jaramillo: Se incluye RN Contrato Nuevo American Airlines
--	2022-02-04	Sebastián Jaramillo: Nueva RN Ultra Air
--	2022-09-28	Sebastián Jaramillo: Se adicionan RN Arajet
--	2023-02-13	Sebastián Jaramillo: Se configura nuevo contrato de Avianca 2023 "TAKE OFF 20230201" y Regional Express se integra como un "facturar a" más de Avianca
--	2023-02-27	Sebastián Jaramillo: Se configura nueva logica en Avianca para identificar transitos ferry o de traslado
--
-- ===================================================================================================================================================================================		
--	SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_CentralizedOfficeService](1333595, 1, 1, 1, 55, '2021-02-07', '2021-02-07 18:27', '2021-02-07 19:22')
--
ALTER FUNCTION  [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_ServiceTypeV2](
	@ServiceHeaderId INT,
	@ServiceType INT,
	@CompanyId INT,
	@BillingToCompany INT,
	@AirportId INT,
	@DateService DATE
)
RETURNS @T_RESULTADO TABLE(
		CollectServiceType BIT, 
		ServiceTypeOrigConsideration INT, 
		ConsiderationPercentaje NVARCHAR(20), 
		Consideration NVARCHAR(MAX),
		AdditionalInfo NVARCHAR(60)
)
AS
BEGIN
	-- =====================
	-- MANTENIMIENTO TTO
	-- =====================
	IF (@ServiceType = 24)
	BEGIN
		IF (@CompanyId = 9 AND @BillingToCompany = 9) --COPA A COPA
		BEGIN
			IF ((@DateService BETWEEN '2019-12-01' AND '2020-12-13') AND @AirportId = 5)
			BEGIN
				INSERT @T_RESULTADO SELECT 0, NULL, NULL, NULL, NULL
				RETURN
			END

			INSERT @T_RESULTADO SELECT 1, NULL, NULL, NULL, NULL
			RETURN
		END

		IF (@CompanyId = 72 AND @BillingToCompany = 56) --WINGO A AEROREPUBLICA
		BEGIN
			IF (@DateService <= '2020-12-13')
			BEGIN
				INSERT @T_RESULTADO SELECT 0, NULL, NULL, NULL, NULL --NO SE COBRA ACA DADO QUE SE MANEJA COBRO FIJO CONJUNTO CON COPA
				RETURN
			END

			INSERT @T_RESULTADO SELECT 1, NULL, NULL, NULL, NULL
			RETURN
		END

		--VIVACOLOMBIA ADZ = 5, CTG =17, MTR = 40, BGA = 11, PEI = 45, SMR = 55, RCH = 51, BAQ = 10   CUC = 18
		IF (@CompanyId = 60 AND @BillingToCompany = 90 AND @AirportId IN (5, 17, 40, 11, 45, 55, 51, 10, 18)) 
		BEGIN
			INSERT @T_RESULTADO SELECT 0, NULL, NULL, NULL, NULL --NO SE COBRA ACA DADO QUE SE MANEJA COBRO FIJO
			RETURN
		END

		--EN AT 206 ES ARUBA
		IF (@CompanyId = 205 AND @BillingToCompany = 205 AND @AirportId IN (17)) --VIVAPERU CTG
		BEGIN
			INSERT @T_RESULTADO SELECT 0, NULL, NULL, NULL, NULL --NO SE COBRA ACA DADO QUE SE MANEJA COBRO FIJO
			RETURN
		END

		INSERT @T_RESULTADO SELECT 1, NULL, NULL, NULL, NULL
		RETURN
	END

	-- ======================
	-- MANTENIMIENTO PERNOCTA
	-- ======================
	IF (@ServiceType IN (25/*Mantenimiento pernocta*/, 28 /*MANTENIMIENTO PERNOCTA (36H)*/, 29 /*MANTENIMIENTO PERNOCTA (48H)*/))
	BEGIN
		IF (@CompanyId = 9 AND @BillingToCompany = 9) --COPA A COPA
		BEGIN
			IF ((@DateService BETWEEN '2019-12-01' AND '2020-12-13') AND @AirportId = 5)
			BEGIN
				INSERT @T_RESULTADO SELECT 0, NULL, NULL, NULL, NULL
				RETURN
			END

			INSERT @T_RESULTADO SELECT 1, NULL, NULL, NULL, NULL
			RETURN
		END

		IF (@CompanyId = 72 AND @BillingToCompany = 56) --WINGO A AEROREPUBLICA
		BEGIN
			IF (@DateService <= '2020-12-13')
			BEGIN
				INSERT @T_RESULTADO SELECT 0, NULL, NULL, NULL, NULL --NO SE COBRA ACA DADO QUE SE MANEJA COBRO FIJO CONJUNTO CON COPA
				RETURN
			END

			INSERT @T_RESULTADO SELECT 1, NULL, NULL, NULL, NULL
			RETURN
		END

		--POR DEFECTO PARA LOS DEMÁS COMPAÑIAS SE COBRAN
		INSERT @T_RESULTADO SELECT 1, NULL, NULL, NULL, NULL
		RETURN
	END

	-- =====================
	-- MANTENIMIENTO TTO ON CALL
	-- =====================
	IF (@ServiceType = 27)
	BEGIN
		IF (@CompanyId = 60 AND @BillingToCompany = 90 AND @AirportId IN (10,11,17,18,40,45,51,55)) --VIVACOLOMBIA MTR, BGA, PEI, SMR, RCH, CUC, CTG, BAQ
		BEGIN
			INSERT @T_RESULTADO SELECT 0, NULL, NULL, NULL, NULL --NO SE MANEJA ACA EL COBRO DADO QUE SE MANEJA COMO BOLSA PARA ESTAS BASES
			RETURN
		END

		INSERT @T_RESULTADO SELECT 1, NULL, NULL, NULL, NULL
		RETURN
	END

	-- =====================
	-- ESCALA TÉCNICA
	-- =====================
	IF (@ServiceType = 5)
	BEGIN
		IF (@CompanyId = 272 /*ARAJET*/ AND @BillingToCompany = 272 /*ARAJET*/)                            
		BEGIN
			IF (@DateService >= '2022-09-15')
			BEGIN
				IF	(	SELECT  COUNT(DS.DetalleServicioId)
						FROM	CIOServicios.DetalleServicio DS
						WHERE	DS.TipoActividadId IN (7,8,43,41) AND DS.Activo = 1 AND DS.EncabezadoServicioId = @ServiceHeaderId  ) >= 1  /*(Descargue de Equipaje / Carga) - (Cargue de Equipaje / Carga) - (Finaliza Desabordaje) - (Llamada a Bordo)*/
					INSERT @T_RESULTADO SELECT 1, 1, '100%', NULL, NULL
				ELSE
					INSERT @T_RESULTADO SELECT 1, 1, '30%', NULL, NULL
			END

			RETURN
		END

		IF (@CompanyId = 259 /*ULTRA AIR*/ AND @BillingToCompany = 259 /*ULTRA AIR*/)                            
		BEGIN
			IF (@DateService >= '2022-01-20')
			BEGIN
				IF	(	SELECT  COUNT(DS.DetalleServicioId)
						FROM	CIOServicios.DetalleServicio DS
						WHERE	DS.TipoActividadId IN (7,8,43,41) AND DS.Activo = 1 AND DS.EncabezadoServicioId = @ServiceHeaderId  ) >= 1  /*(Descargue de Equipaje / Carga) - (Cargue de Equipaje / Carga) - (Finaliza Desabordaje) - (Llamada a Bordo)*/
					INSERT @T_RESULTADO SELECT 1, 1, '100%', NULL, NULL
				ELSE
					INSERT @T_RESULTADO SELECT 1, 1, '25%', NULL, NULL
			END

			RETURN
		END

		IF (@CompanyId = 43 /*AMERICAN AIRLINES*/ AND @BillingToCompany = 43 /*AMERICAN AIRLINES*/)                            
		BEGIN
			IF (@DateService >= '2021-12-04')
			BEGIN
				IF	(	SELECT  COUNT(DS.DetalleServicioId)
						FROM	CIOServicios.DetalleServicio DS
						WHERE	DS.TipoActividadId IN (7,8,43,41) AND DS.Activo = 1 AND DS.EncabezadoServicioId = @ServiceHeaderId  ) >= 1  /*(Descargue de Equipaje / Carga) - (Cargue de Equipaje / Carga) - (Finaliza Desabordaje) - (Llamada a Bordo)*/
					INSERT @T_RESULTADO SELECT 1, 1, '100%', NULL, NULL
				ELSE
					INSERT @T_RESULTADO SELECT 1, 1, '25%', NULL, NULL
			END

			RETURN
		END

		IF (@CompanyId = 69 /*SARPA*/ AND @BillingToCompany = 69 /*SARPA*/)                            
		BEGIN
			IF (@DateService >= '2021-10-01')
			BEGIN
				INSERT @T_RESULTADO SELECT 1, 1, '50%', NULL, NULL
			END

			RETURN
		END

		IF	(	(@CompanyId = 1 AND @BillingToCompany = 1) --AVIANCA A AVIANCA
			OR	(@CompanyId = 1 AND @BillingToCompany = 193 AND @DateService >= '2023-02-01') --AVIANCA S.A A REGIONAL EXPRESS
			OR	(@CompanyId = 42 AND @BillingToCompany = 1 AND @DateService >= '2023-02-01') --TACA A AVIANCA S.A.
			OR	(@CompanyId = 47 AND @BillingToCompany = 1 AND @DateService >= '2023-02-01') --AEROGAL S.A A AVIANCA S.A.
			OR	(@CompanyId = 47 AND @BillingToCompany = 1) --AEROGAL A AVIANCA
			OR	(@CompanyId = 42 AND @BillingToCompany = 42) --TACA A TACA 
			OR	(@CompanyId = 42 AND @BillingToCompany = 54) --TACA A TRANSAMERICAN 
			OR	(@CompanyId = 41 AND @BillingToCompany = 41) --LACSA A LACSA
			OR	(@BillingToCompany = 1 AND @CompanyId <> 193 ) --COMPAÑIAS QUE SE FACTURAN A AVIANCA SERVICES
		) 
		BEGIN
			INSERT @T_RESULTADO SELECT 1, 1/*TRANSITO*/, '30%', '30% tránsito (si se produce cargue y/o descargue)', NULL --ESCALA TECNICA REPRESENTA UN PORCENTAJE DEL TRANSITO
			RETURN
		END

		IF (@CompanyId = 69 /*SARPA*/ AND @BillingToCompany = 69 /*SARPA*/)                             
		BEGIN
			INSERT @T_RESULTADO SELECT 1, 1, '50%', '50% tránsito (si cargue y/o descargue, embarque y/o desembarque pax)', NULL
			RETURN
		END

		IF (@CompanyId = 60 /*VIVA COLOMBIA*/ AND @BillingToCompany = 90 /*FAST COLOMBIA*/)                             
		BEGIN
			INSERT @T_RESULTADO SELECT 1, 1, '50%', '50% tránsito (si cargue y/o descargue, embarque y/o desembarque pax)', NULL
			RETURN
		END
		
		--Ajuste solicitado por contabilidad, cambia el % de cobro del 30 al 20 desde '2019-12-01' para Regional
		IF	( @CompanyId = 193 AND @BillingToCompany = 1 AND @DateService >= '2019-12-01' AND  @AirportId NOT IN (3,45) /*MDE - PEI*/) --REGIONAL EXPRESS AMERICAS A AVIANCA
		BEGIN
			INSERT @T_RESULTADO SELECT 1, 1, '20%', '20% tránsito (si cargue y/o descargue, embarque y/o desembarque pax)', NULL
			RETURN
		END
      
        IF	( @CompanyId = 193 AND @BillingToCompany = 1 AND (@DateService < '2019-12-01' OR @AirportId IN (3,45) /*MDE - PEI*/)) --REGIONAL EXPRESS AMERICAS A AVIANCA
		BEGIN
			INSERT @T_RESULTADO SELECT 1, 1, '30%', '30% tránsito (si cargue y/o descargue, embarque y/o desembarque pax)', NULL
			RETURN
		END
			        
		IF (@CompanyId = 255 /*VIVAAEROBUS*/ AND @BillingToCompany = 255 /*VIVAAEROBUS*/)                             
		BEGIN
			INSERT @T_RESULTADO SELECT 1, 1, '50%', '50% tránsito (si se produce cargue y/o descargue)', NULL
			RETURN
		END

		--POR DEFECTO PARA LOS DEMÁS COMPAÑIAS
		INSERT @T_RESULTADO SELECT 1, 1, NULL, NULL, NULL
		RETURN
	END

	-- ========================================
	-- REGRESOS A PLATAFORMA / RETORNO A RAMPA
	-- ========================================
	IF (@ServiceType = 6)
	BEGIN
		IF (@CompanyId = 272 /*ARAJET*/ AND @BillingToCompany = 272 /*ARAJET*/)                        
		BEGIN
			IF (@DateService >= '2022-09-15')
			BEGIN
				IF	(	SELECT  COUNT(DS.DetalleServicioId)
						FROM	CIOServicios.DetalleServicio DS
						WHERE	DS.TipoActividadId IN (7,8) AND DS.Activo = 1 AND DS.EncabezadoServicioId = @ServiceHeaderId  ) >= 1  /*(Descargue de Equipaje / Carga) - (Cargue de Equipaje / Carga)*/
					INSERT @T_RESULTADO SELECT 1, 1, NULL, NULL, NULL
				ELSE
					INSERT @T_RESULTADO SELECT 0, 1, NULL, NULL, NULL
			END

			RETURN
		END

		IF (@CompanyId = 259 /*ULTRA AIR*/ AND @BillingToCompany = 259 /*ULTRA AIR*/)                            
		BEGIN
			IF (@DateService >= '2022-01-20')
			BEGIN
				IF	(	SELECT  COUNT(DS.DetalleServicioId)
						FROM	CIOServicios.DetalleServicio DS
						WHERE	DS.TipoActividadId IN (7,8) AND DS.Activo = 1 AND DS.EncabezadoServicioId = @ServiceHeaderId  ) >= 1  /*(Descargue de Equipaje / Carga) - (Cargue de Equipaje / Carga)*/
					INSERT @T_RESULTADO SELECT 1, 1, NULL, NULL, NULL
				ELSE
					INSERT @T_RESULTADO SELECT 0, 1, NULL, NULL, NULL
			END

			RETURN
		END

		IF (@CompanyId = 43 /*AMERICAN AIRLINES*/ AND @BillingToCompany = 43 /*AMERICAN AIRLINES*/)                            
		BEGIN
			IF (@DateService >= '2021-12-04')
			BEGIN
				IF	(	SELECT  COUNT(DS.DetalleServicioId)
						FROM	CIOServicios.DetalleServicio DS
						WHERE	DS.TipoActividadId IN (7,8) AND DS.Activo = 1 AND DS.EncabezadoServicioId = @ServiceHeaderId  ) >= 1  /*(Descargue de Equipaje / Carga) - (Cargue de Equipaje / Carga)*/
					INSERT @T_RESULTADO SELECT 1, 1, NULL, NULL, NULL
				ELSE
					INSERT @T_RESULTADO SELECT 0, 1, NULL, NULL, NULL
			END

			RETURN
		END

		IF (@CompanyId = 69 /*SARPA*/ AND @BillingToCompany = 69 /*SARPA*/)                            
		BEGIN
			IF (@DateService >= '2021-10-01')
			BEGIN
				IF	(	SELECT  COUNT(DS.DetalleServicioId)
						FROM	CIOServicios.DetalleServicio DS
						WHERE	DS.TipoActividadId IN (7,8,43,41) AND DS.Activo = 1 AND DS.EncabezadoServicioId = @ServiceHeaderId  ) >= 1  /*(Descargue de Equipaje / Carga) - (Cargue de Equipaje / Carga) - (Finaliza Desabordaje) - (Llamada a Bordo)*/
					INSERT @T_RESULTADO SELECT 1, NULL, NULL, NULL, NULL --COBRA REGRESO A PLATAFORMA
				ELSE
					INSERT @T_RESULTADO SELECT 0, NULL, NULL, NULL, NULL --NO COBRA REGRESO A PLATAFORMA
			END

			RETURN
		END

		IF (@CompanyId = 9/*COPA*/ AND @BillingToCompany IN (9, 56) /*COPA - AEROREPUBLICA*/) 
		BEGIN
			INSERT @T_RESULTADO SELECT 0, NULL, NULL, NULL, NULL --NO SE COBRAN LOS REGRESOS A PLATAFORMA EN NINGÚN CASO
			RETURN
		END
	
		IF (@CompanyId = 44 /*LAN AIRLINES*/ AND @BillingToCompany IN (44, 139) /*LAN AIRLINES - LAN PERU*/) 
		BEGIN

			IF	(	@AirportId = 25 --AXM
				AND @DateService >= '2021-10-27'
				AND	(	SELECT  COUNT(DS.DetalleServicioId)
						FROM	CIOServicios.DetalleServicio DS /*(Descargue de Equipaje / Carga) - (Cargue de Equipaje / Carga)*/
						WHERE	DS.TipoActividadId IN (7,8) AND DS.Activo = 1 AND DS.EncabezadoServicioId = @ServiceHeaderId ) >= 1 --SE VALIDA SI HUBO CARGUE, DESCARGUE
				)
			BEGIN
				INSERT @T_RESULTADO SELECT 1, 1, '30%', '30% transito (si cargue y/o descargue)', NULL
				RETURN
			END

			IF	(	SELECT  COUNT(DS.DetalleServicioId)
					FROM	CIOServicios.DetalleServicio DS /*(Descargue de Equipaje / Carga) - (Cargue de Equipaje / Carga) - (Finaliza Desabordaje) - (Llamada a Bordo)*/
					WHERE	DS.TipoActividadId IN (7,8,43,41) AND DS.Activo = 1 AND DS.EncabezadoServicioId = @ServiceHeaderId ) >= 1 --SE VALIDA SI HUBO CARGUE, DESCARGUE, EMBARQUE Y/O DESEMBARQUE DE PAX
				INSERT @T_RESULTADO SELECT 1, 1, '50%', '50% transito (si cargue y/o descargue y/o embarque y/o desembarque de pax)', NULL
			ELSE 
				INSERT @T_RESULTADO SELECT 0, 1, NULL, NULL, NULL

			RETURN
		END

		IF	(	(@CompanyId = 1 AND @BillingToCompany = 1) --AVIANCA A AVIANCA
			OR	(@CompanyId = 1 AND @BillingToCompany = 193 AND @DateService >= '2023-02-01') --AVIANCA S.A A REGIONAL EXPRESS
			OR	(@CompanyId = 42 AND @BillingToCompany = 1 AND @DateService >= '2023-02-01') --TACA A AVIANCA S.A.
			OR	(@CompanyId = 47 AND @BillingToCompany = 1 AND @DateService >= '2023-02-01') --AEROGAL S.A A AVIANCA S.A.
			OR	(@CompanyId = 47 AND @BillingToCompany = 1) --AEROGAL A AVIANCA
			OR	(@CompanyId = 42 AND @BillingToCompany = 42) --TACA A TACA 
			OR	(@CompanyId = 42 AND @BillingToCompany = 54) --TACA A TRANSAMERICAN 
			OR	(@CompanyId = 41 AND @BillingToCompany = 41) --LACSA A LACSA
			OR	(@BillingToCompany = 1 AND @CompanyId <> 193) --COMPAÑIAS QUE SE FACTURAN A AVIANCA SERVICES
		) 
		BEGIN
			IF	(	SELECT  COUNT(DS.DetalleServicioId)
					FROM	CIOServicios.DetalleServicio DS /*(Descargue de Equipaje / Carga) - (Cargue de Equipaje / Carga)*/
					WHERE	DS.TipoActividadId IN (7,8) AND DS.Activo = 1 AND DS.EncabezadoServicioId = @ServiceHeaderId ) >= 1 --SE VALIDA SI HUBO CARGUE O DE DESCARGUE
				INSERT @T_RESULTADO SELECT 1, 1/*TRANSITO*/, '30%', '30% transito (si cargue y/o descargue)', NULL --REGRESO A PLATAFORMA REPRESENTA UN PORCENTAJE DEL TRANSITO
			ELSE
				INSERT @T_RESULTADO SELECT 0, 1, NULL, NULL, NULL

			RETURN
		END

		--Ajuste solicitado por contabilidad, cambia el % de cobro del 30 al 20 desde '2019-12-01' para Regional
		IF	( @CompanyId = 193 AND @BillingToCompany = 1 AND @DateService >= '2019-12-01' AND @AirportId NOT IN (3,45) /*MDE - PEI*/) --REGIONAL EXPRESS AMERICAS A AVIANCA
			BEGIN
			   INSERT @T_RESULTADO SELECT 1, 1, '20%', '20% tránsito (si cargue y/o descargue, embarque y/o desembarque pax)', NULL
			   RETURN
			END

        IF	( @CompanyId = 193 AND @BillingToCompany = 1 AND (@DateService < '2019-12-01' OR @AirportId IN (3,45) /*MDE - PEI*/)) --REGIONAL EXPRESS AMERICAS A AVIANCA
			BEGIN
			   INSERT @T_RESULTADO SELECT 1, 1, '30%', '30% tránsito (si cargue y/o descargue, embarque y/o desembarque pax)', NULL
			   RETURN
			END
			     

		IF (@CompanyId = 11 AND @BillingToCompany = 11) --EASY FLY                              
		BEGIN
			IF	(	SELECT  COUNT(DS.DetalleServicioId)
					FROM	CIOServicios.DetalleServicio DS /*(Descargue de Equipaje / Carga) - (Cargue de Equipaje / Carga) - (Finaliza Desabordaje) - (Llamada a Bordo)*/
					WHERE	DS.TipoActividadId IN (7,8,43,41) AND DS.Activo = 1 AND DS.EncabezadoServicioId = @ServiceHeaderId  ) >= 1 --SE VALIDA SI HUBO CARGUE Y/O DESCARGUE
				INSERT @T_RESULTADO SELECT 1, 1/*TRANSITO*/, '50%', '50% transito (si cargue y/o descargue y/o embarque y/o desembarque de pax)', NULL --REGRESO A PLATAFORMA REPRESENTA UN PORCENTAJE DEL TRANSITO
			ELSE
				INSERT @T_RESULTADO SELECT 0, 1, NULL, NULL, NULL

			RETURN
		END

		IF (@CompanyId = 81 AND @BillingToCompany = 81) --JET SMART                              
		BEGIN
			IF	(	SELECT  COUNT(DS.DetalleServicioId)
					FROM	CIOServicios.DetalleServicio DS /*(Descargue de Equipaje / Carga) - (Cargue de Equipaje / Carga) - (Finaliza Desabordaje) - (Llamada a Bordo)*/
					WHERE	DS.TipoActividadId IN (7,8,43,41) AND DS.Activo = 1 AND DS.EncabezadoServicioId = @ServiceHeaderId  ) >= 1 --SE VALIDA SI HUBO CARGUE Y/O DESCARGUE
				INSERT @T_RESULTADO SELECT 1, 1/*TRANSITO*/, '30%', '30% transito (si cargue y/o descargue y/o embarque y/o desembarque de pax)', NULL --REGRESO A PLATAFORMA REPRESENTA UN PORCENTAJE DEL TRANSITO
			ELSE
				INSERT @T_RESULTADO SELECT 0, 1, NULL, NULL, NULL

			RETURN
		END

		IF (@CompanyId = 60 /*VIVA COLOMBIA*/ AND @BillingToCompany = 90 /*FAST COLOMBIA*/AND @DateService >= '2017-11-01') -- VIVACOLOMBIA                            
		BEGIN
			INSERT @T_RESULTADO SELECT 0, 1, NULL, NULL, NULL --NO SE COBRAN CON VIVA LOS REGRESOS A PLATAFORMA DESDE 2017-11-01 YA SI SE PRESENTAN LOS EVENTOS DE CARGUE, DESCARGUE, EMBARQUE Y/O DESEMBARQUE DE PAX SE DEBE INGRESAR COMO TRANSITO
			RETURN
		END

		IF (@CompanyId = 255 /*VIVAAEROBUS*/ AND @BillingToCompany = 255 /*VIVAAEROBUS*/)                             
		BEGIN
			IF	(	SELECT  COUNT(DS.DetalleServicioId)
					FROM	CIOServicios.DetalleServicio DS /*(Descargue de Equipaje / Carga) - (Cargue de Equipaje / Carga)*/
					WHERE	DS.TipoActividadId IN (7,8) AND DS.Activo = 1 AND DS.EncabezadoServicioId = @ServiceHeaderId ) >= 1 --SE VALIDA SI HUBO CARGUE O DE DESCARGUE
				INSERT @T_RESULTADO SELECT 1, 1/*TRANSITO*/, '50%', '50% transito (si cargue y/o descargue)', NULL --REGRESO A PLATAFORMA REPRESENTA UN PORCENTAJE DEL TRANSITO
			ELSE
				INSERT @T_RESULTADO SELECT 0, 1, NULL, NULL, NULL

			RETURN
		END

		--POR DEFECTO PARA LAS DEMÁS COMPAÑIAS
		IF	(	SELECT  COUNT(DS.DetalleServicioId)
					FROM	CIOServicios.DetalleServicio DS /*(Descargue de Equipaje / Carga) - (Cargue de Equipaje / Carga) - (Finaliza Desabordaje) - (Llamada a Bordo)*/
					WHERE	DS.TipoActividadId IN (7,8,43,41) AND DS.Activo = 1 AND DS.EncabezadoServicioId = @ServiceHeaderId ) >= 1 --SE VALIDA SI HUBO CARGUE, DESCARGUE, EMBARQUE Y/O DESEMBARQUE DE PAX
			INSERT @T_RESULTADO SELECT 1, 1, NULL, NULL, NULL
		ELSE
			INSERT @T_RESULTADO SELECT 0, 1, NULL, NULL, NULL
		
		RETURN
	END

	-- ==============================================
	-- COBROS PARCIALES EN LA SALIDA (REGLA ESPECIAL)
	-- ==============================================
	INSERT	@T_RESULTADO
	SELECT	R.CollectServiceType, R.ServiceTypeOrigConsideration, R.ConsiderationPercentaje, R.Consideration, R.AdditionalInfo
	FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_ServiceType_PartialCollectionV2](@ServiceHeaderId, @ServiceType, @CompanyId, @BillingToCompany, @AirportId, @DateService, 1) R
	IF EXISTS (SELECT TOP(1) 1 R FROM @T_RESULTADO)
	BEGIN
		RETURN
	END

	DECLARE		@ServicioCompleto BIT = NULL
	DECLARE		@ServicioTraslado BIT = NULL
	DECLARE		@ServicioFerry BIT = NULL

	-- ==============================================
	-- TRANSITOS
	-- ==============================================
	IF (@ServiceType = 1)
	BEGIN		
		IF	(	(@CompanyId = 1 AND @BillingToCompany = 1 AND @DateService >= '2023-03-01') --AVIANCA A AVIANCA
			OR	(@CompanyId = 1 AND @BillingToCompany = 193 AND @DateService >= '2023-03-01') --AVIANCA S.A A REGIONAL EXPRESS
			OR	(@CompanyId = 42 AND @BillingToCompany = 1 AND @DateService >= '2023-03-01') --TACA A AVIANCA S.A.
			OR	(@CompanyId = 47 AND @BillingToCompany = 1 AND @DateService >= '2023-03-01') --AEROGAL S.A A AVIANCA S.A.
			)
		BEGIN
			SELECT	@ServicioCompleto = SSA.ServiceComplete
				,	@ServicioTraslado = SSA.ServiceTransfer
				,	@ServicioFerry = SSA.ServiceFerry
			FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_ServiceType_ScopeServiceAttended](@ServiceHeaderId, @ServiceType) SSA

			IF (@ServicioCompleto = 1)
			BEGIN
				INSERT @T_RESULTADO SELECT 1, NULL, NULL, NULL, NULL
				RETURN
			END

			IF (@ServicioFerry = 1)
			BEGIN
				INSERT @T_RESULTADO SELECT 1, NULL, '50%', CONCAT('50%', '50% transito (si no hubo embarque o desembarque de pax)'), ' FERRY 50%'
				RETURN
			END

			IF (@ServicioTraslado = 1)
			BEGIN
				INSERT @T_RESULTADO SELECT 1, NULL, '15%', CONCAT('15%', '15% transito (si no hubo embarque ni desembarque de pax)'), ' TRASLADO 15%'
				RETURN
			END
		END

		--SI CAE ACA ES PORQUE NO HAY VALIDACIONES ESPACIALES DE MANERA EXPLICITA PARA TRANSITO Y CONTINUA HASTA LLEGAR A LA REGLA POR DEFECTO AL FINAL
	END

	-- ==============================================
	-- PERNOCTA
	-- ==============================================
	IF (@ServiceType = 23)
	BEGIN		
		IF	(	(@CompanyId = 1 AND @BillingToCompany = 1 AND @DateService >= '2023-03-01') --AVIANCA A AVIANCA
			OR	(@CompanyId = 1 AND @BillingToCompany = 193 AND @DateService >= '2023-03-01') --AVIANCA S.A A REGIONAL EXPRESS
			OR	(@CompanyId = 42 AND @BillingToCompany = 1 AND @DateService >= '2023-03-01') --TACA A AVIANCA S.A.
			OR	(@CompanyId = 47 AND @BillingToCompany = 1 AND @DateService >= '2023-03-01') --AEROGAL S.A A AVIANCA S.A.
			)
		BEGIN
			SELECT	@ServicioCompleto = SSA.ServiceComplete
				,	@ServicioTraslado = SSA.ServiceTransfer
				,	@ServicioFerry = SSA.ServiceFerry
			FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_ServiceType_ScopeServiceAttended](@ServiceHeaderId, @ServiceType) SSA

			IF (@ServicioCompleto = 1)
			BEGIN
				INSERT @T_RESULTADO SELECT 1, NULL, NULL, NULL, NULL
				RETURN
			END

			IF (@ServicioFerry = 1)
			BEGIN
				INSERT @T_RESULTADO SELECT 1, NULL, '50%', CONCAT('50%', '50% transito (si no hubo embarque o desembarque de pax)'), ' FERRY 50%'
				RETURN
			END

			IF (@ServicioTraslado = 1)
			BEGIN
				INSERT @T_RESULTADO SELECT 1, NULL, '15%', CONCAT('15%', '15% transito (si no hubo embarque ni desembarque de pax)'), ' TRASLADO 15%'
				RETURN
			END
		END

		--SI CAE ACA ES PORQUE NO HAY VALIDACIONES ESPACIALES DE MANERA EXPLICITA PARA PERNOCTA Y CONTINUA HASTA LLEGAR A LA REGLA POR DEFECTO AL FINAL
	END

	-- =======================================
	-- POR DEFECTO TIPOS DE SERVICIO RESTANTES
	-- =======================================
	INSERT @T_RESULTADO SELECT 1, NULL, NULL, NULL, NULL
	RETURN
END